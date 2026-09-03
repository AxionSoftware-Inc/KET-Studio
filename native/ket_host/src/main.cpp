#include "pty_session.hpp"

#include <array>
#include <atomic>
#include <cstdint>
#include <iostream>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace {

constexpr std::uint32_t kMaxFrame = 8U * 1024U * 1024U;
std::mutex g_write_mutex;

std::string json_escape(const std::string& value) {
  std::string out;
  out.reserve(value.size() + 16);
  for (const unsigned char ch : value) {
    switch (ch) {
      case '\\': out += "\\\\"; break;
      case '"': out += "\\\""; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (ch >= 0x20) out.push_back(static_cast<char>(ch));
        break;
    }
  }
  return out;
}

std::string extract_string(const std::string& json, const std::string& key) {
  const auto marker = '"' + key + '"';
  auto p = json.find(marker);
  if (p == std::string::npos) return {};
  p = json.find(':', p + marker.size());
  if (p == std::string::npos) return {};
  p = json.find('"', p + 1);
  if (p == std::string::npos) return {};
  ++p;
  std::string out;
  bool escape = false;
  for (; p < json.size(); ++p) {
    const char c = json[p];
    if (escape) {
      switch (c) {
        case 'n': out.push_back('\n'); break;
        case 'r': out.push_back('\r'); break;
        case 't': out.push_back('\t'); break;
        default: out.push_back(c); break;
      }
      escape = false;
    } else if (c == '\\') {
      escape = true;
    } else if (c == '"') {
      break;
    } else {
      out.push_back(c);
    }
  }
  return out;
}

int extract_int(const std::string& json, const std::string& key, int fallback) {
  const auto marker = '"' + key + '"';
  auto p = json.find(marker);
  if (p == std::string::npos) return fallback;
  p = json.find(':', p + marker.size());
  if (p == std::string::npos) return fallback;
  ++p;
  while (p < json.size() && (json[p] == ' ' || json[p] == '\t')) ++p;
  bool negative = false;
  if (p < json.size() && json[p] == '-') { negative = true; ++p; }
  int value = 0;
  bool any = false;
  while (p < json.size() && json[p] >= '0' && json[p] <= '9') {
    any = true;
    value = value * 10 + (json[p++] - '0');
  }
  return any ? (negative ? -value : value) : fallback;
}

bool extract_bool(const std::string& json, const std::string& key, bool fallback) {
  const auto marker = '"' + key + '"';
  auto p = json.find(marker);
  if (p == std::string::npos) return fallback;
  p = json.find(':', p + marker.size());
  if (p == std::string::npos) return fallback;
  ++p;
  while (p < json.size() && json[p] == ' ') ++p;
  if (json.compare(p, 4, "true") == 0) return true;
  if (json.compare(p, 5, "false") == 0) return false;
  return fallback;
}

const char* kB64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
std::string b64_encode(const std::vector<std::uint8_t>& data) {
  std::string out;
  out.reserve(((data.size() + 2) / 3) * 4);
  std::uint32_t acc = 0;
  int bits = 0;
  for (const auto byte : data) {
    acc = (acc << 8) | byte;
    bits += 8;
    while (bits >= 6) {
      bits -= 6;
      out.push_back(kB64[(acc >> bits) & 0x3F]);
    }
  }
  if (bits > 0) out.push_back(kB64[(acc << (6 - bits)) & 0x3F]);
  while (out.size() % 4 != 0) out.push_back('=');
  return out;
}

int b64_value(char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '+') return 62;
  if (c == '/') return 63;
  return -1;
}

std::vector<std::uint8_t> b64_decode(const std::string& text) {
  std::vector<std::uint8_t> out;
  std::uint32_t acc = 0;
  int bits = 0;
  for (const char c : text) {
    if (c == '=') break;
    const int v = b64_value(c);
    if (v < 0) continue;
    acc = (acc << 6) | static_cast<std::uint32_t>(v);
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push_back(static_cast<std::uint8_t>((acc >> bits) & 0xFF));
    }
  }
  return out;
}

bool read_exact(char* dst, std::size_t count) {
  std::cin.read(dst, static_cast<std::streamsize>(count));
  return static_cast<std::size_t>(std::cin.gcount()) == count;
}

bool read_frame(std::string& payload) {
  std::array<unsigned char, 4> header{};
  if (!read_exact(reinterpret_cast<char*>(header.data()), header.size())) return false;
  const std::uint32_t length = (static_cast<std::uint32_t>(header[0]) << 24) |
                               (static_cast<std::uint32_t>(header[1]) << 16) |
                               (static_cast<std::uint32_t>(header[2]) << 8) |
                               static_cast<std::uint32_t>(header[3]);
  if (length == 0 || length > kMaxFrame) throw std::runtime_error("invalid frame length");
  payload.resize(length);
  return read_exact(payload.data(), length);
}

void write_frame(const std::string& json) {
  if (json.size() > kMaxFrame) throw std::runtime_error("output frame too large");
  std::lock_guard lock(g_write_mutex);
  const auto n = static_cast<std::uint32_t>(json.size());
  const std::array<unsigned char, 4> header{
      static_cast<unsigned char>((n >> 24) & 0xFF),
      static_cast<unsigned char>((n >> 16) & 0xFF),
      static_cast<unsigned char>((n >> 8) & 0xFF),
      static_cast<unsigned char>(n & 0xFF)};
  std::cout.write(reinterpret_cast<const char*>(header.data()), header.size());
  std::cout.write(json.data(), static_cast<std::streamsize>(json.size()));
  std::cout.flush();
}

std::string message(const std::string& type, const std::string& request_id,
                    const std::string& session_id, const std::string& payload) {
  return "{\"type\":\"" + type + "\",\"requestId\":\"" + json_escape(request_id) +
         "\"" + (session_id.empty() ? "" : ",\"sessionId\":\"" + json_escape(session_id) + "\"") +
         ",\"payload\":" + payload + "}";
}

}  // namespace

int main() {
  std::ios::sync_with_stdio(false);
  std::cin.tie(nullptr);

  std::unordered_map<std::string, std::shared_ptr<ket::PtySession>> sessions;
  std::atomic_bool shutting_down{false};

  try {
    std::string frame;
    while (!shutting_down && read_frame(frame)) {
      const auto type = extract_string(frame, "type");
      const auto request_id = extract_string(frame, "requestId");
      const auto session_id = extract_string(frame, "sessionId");

      try {
        if (type == "hello") {
          write_frame(message("hello", request_id, "", "{\"protocolVersion\":1}"));
        } else if (type == "openTerminal") {
          ket::LaunchSpec spec;
          spec.executable = extract_string(frame, "executable");
          spec.working_directory = extract_string(frame, "workingDirectory");
          spec.size.columns = static_cast<std::uint16_t>(extract_int(frame, "columns", 120));
          spec.size.rows = static_cast<std::uint16_t>(extract_int(frame, "rows", 32));
          auto owned = ket::create_pty_session(spec);
          auto session = std::shared_ptr<ket::PtySession>(std::move(owned));
          const auto id = session->id();
          sessions[id] = session;
          write_frame(message("terminalOpened", request_id, id, "{}"));

          std::thread([session, request_id]() {
            try {
              std::array<std::uint8_t, 8192> buffer{};
              for (;;) {
                const auto count = session->read(buffer);
                if (count == 0) break;
                std::vector<std::uint8_t> chunk(buffer.begin(), buffer.begin() + static_cast<std::ptrdiff_t>(count));
                write_frame(message("terminalOutput", "event", session->id(),
                                    "{\"data\":\"" + b64_encode(chunk) + "\"}"));
              }
              const int code = session->wait();
              write_frame(message("terminalExit", "event", session->id(),
                                  "{\"exitCode\":" + std::to_string(code) + "}"));
            } catch (const std::exception& e) {
              write_frame(message("error", request_id, session->id(),
                                  "{\"message\":\"" + json_escape(e.what()) + "\"}"));
            }
          }).detach();
        } else if (type == "terminalInput") {
          sessions.at(session_id)->write(b64_decode(extract_string(frame, "data")));
        } else if (type == "terminalResize") {
          sessions.at(session_id)->resize({
              static_cast<std::uint16_t>(extract_int(frame, "columns", 120)),
              static_cast<std::uint16_t>(extract_int(frame, "rows", 32))});
        } else if (type == "terminalInterrupt") {
          sessions.at(session_id)->interrupt();
        } else if (type == "terminalTerminate") {
          sessions.at(session_id)->terminate(extract_bool(frame, "force", false));
        } else if (type == "shutdown") {
          shutting_down = true;
          for (auto& [id, session] : sessions) {
            (void)id;
            try { session->terminate(true); } catch (...) {}
          }
          write_frame(message("shutdown", request_id, "", "{}"));
        } else {
          write_frame(message("error", request_id, session_id,
                              "{\"message\":\"unsupported native host command\"}"));
        }
      } catch (const std::exception& e) {
        write_frame(message("error", request_id, session_id,
                            "{\"message\":\"" + json_escape(e.what()) + "\"}"));
      }
    }
  } catch (const std::exception& e) {
    std::cerr << "ket_host fatal: " << e.what() << '\n';
    return 2;
  }
  return 0;
}
