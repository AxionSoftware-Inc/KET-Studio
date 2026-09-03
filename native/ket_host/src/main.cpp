#include "json_value.hpp"
#include "pty_session.hpp"

#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <unordered_map>
#include <utility>
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
      case '\b': out += "\\b"; break;
      case '\f': out += "\\f"; break;
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
  if (length == 0 || length > kMaxFrame) {
    throw std::runtime_error("invalid native-host frame length");
  }
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
  return "{\"type\":\"" + json_escape(type) + "\",\"requestId\":\"" +
         json_escape(request_id) + "\"" +
         (session_id.empty()
              ? ""
              : ",\"sessionId\":\"" + json_escape(session_id) + "\"") +
         ",\"payload\":" + payload + "}";
}

const ket::json::Value::Object& require_object(const ket::json::Value& value,
                                                const char* context) {
  if (!value.is_object()) throw std::runtime_error(std::string(context) + " must be an object");
  return value.as_object();
}

const ket::json::Value& require_field(const ket::json::Value& object,
                                      std::string_view key) {
  const auto* value = object.find(key);
  if (value == nullptr) throw std::runtime_error("missing required field: " + std::string(key));
  return *value;
}

std::string require_string(const ket::json::Value& object, std::string_view key) {
  const auto& value = require_field(object, key);
  if (!value.is_string()) throw std::runtime_error(std::string(key) + " must be a string");
  return value.as_string();
}

std::string optional_string(const ket::json::Value& object, std::string_view key,
                            std::string fallback = {}) {
  const auto* value = object.find(key);
  if (value == nullptr || value->is_null()) return fallback;
  if (!value->is_string()) throw std::runtime_error(std::string(key) + " must be a string");
  return value->as_string();
}

int optional_int(const ket::json::Value& object, std::string_view key, int fallback) {
  const auto* value = object.find(key);
  if (value == nullptr) return fallback;
  if (!value->is_number()) throw std::runtime_error(std::string(key) + " must be a number");
  const double number = value->as_number();
  if (!std::isfinite(number) || std::floor(number) != number) {
    throw std::runtime_error(std::string(key) + " must be an integer");
  }
  return static_cast<int>(number);
}

bool optional_bool(const ket::json::Value& object, std::string_view key, bool fallback) {
  const auto* value = object.find(key);
  if (value == nullptr) return fallback;
  if (!value->is_bool()) throw std::runtime_error(std::string(key) + " must be a boolean");
  return value->as_bool();
}

std::vector<std::string> optional_string_array(const ket::json::Value& object,
                                                std::string_view key) {
  const auto* value = object.find(key);
  if (value == nullptr) return {};
  if (!value->is_array()) throw std::runtime_error(std::string(key) + " must be an array");
  std::vector<std::string> result;
  result.reserve(value->as_array().size());
  for (const auto& item : value->as_array()) {
    if (!item.is_string()) throw std::runtime_error(std::string(key) + " must contain strings");
    result.push_back(item.as_string());
  }
  return result;
}

std::map<std::string, std::string> optional_string_map(const ket::json::Value& object,
                                                       std::string_view key) {
  const auto* value = object.find(key);
  if (value == nullptr) return {};
  if (!value->is_object()) throw std::runtime_error(std::string(key) + " must be an object");
  std::map<std::string, std::string> result;
  for (const auto& [entry_key, entry_value] : value->as_object()) {
    if (!entry_value.is_string()) {
      throw std::runtime_error(std::string(key) + " values must be strings");
    }
    result.emplace(entry_key, entry_value.as_string());
  }
  return result;
}

const char* kB64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

std::string b64_encode(std::span<const std::uint8_t> data) {
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
    if (v < 0) throw std::runtime_error("invalid base64 terminal payload");
    acc = (acc << 6) | static_cast<std::uint32_t>(v);
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push_back(static_cast<std::uint8_t>((acc >> bits) & 0xFF));
    }
  }
  return out;
}

struct SessionRecord {
  std::shared_ptr<ket::PtySession> session;
  std::jthread reader;
};

SessionRecord& require_session(
    std::unordered_map<std::string, std::unique_ptr<SessionRecord>>& sessions,
    const std::string& id) {
  const auto it = sessions.find(id);
  if (it == sessions.end()) throw std::runtime_error("unknown terminal session: " + id);
  return *it->second;
}

}  // namespace

int main() {
  std::ios::sync_with_stdio(false);
  std::cin.tie(nullptr);

  std::unordered_map<std::string, std::unique_ptr<SessionRecord>> sessions;
  bool shutting_down = false;

  try {
    std::string frame;
    while (!shutting_down && read_frame(frame)) {
      std::string request_id = "unknown";
      std::string session_id;
      try {
        const auto root = ket::json::parse(frame);
        require_object(root, "native-host message");
        const auto type = require_string(root, "type");
        request_id = require_string(root, "requestId");
        session_id = optional_string(root, "sessionId");
        const auto& payload = require_field(root, "payload");
        require_object(payload, "payload");

        if (type == "hello") {
          const int protocol = optional_int(payload, "protocolVersion", -1);
          if (protocol != 1) throw std::runtime_error("unsupported native-host protocol version");
          write_frame(message("hello", request_id, "", "{\"protocolVersion\":1}"));
          continue;
        }

        if (type == "openTerminal") {
          ket::LaunchSpec spec;
          spec.executable = require_string(payload, "executable");
          spec.arguments = optional_string_array(payload, "arguments");
          spec.working_directory = optional_string(payload, "workingDirectory");
          spec.environment = optional_string_map(payload, "environment");
          spec.size.columns = static_cast<std::uint16_t>(optional_int(payload, "columns", 120));
          spec.size.rows = static_cast<std::uint16_t>(optional_int(payload, "rows", 32));

          auto session = std::shared_ptr<ket::PtySession>(ket::create_pty_session(spec));
          const auto id = session->id();
          auto record = std::make_unique<SessionRecord>();
          record->session = session;
          record->reader = std::jthread([session]() {
            try {
              std::array<std::uint8_t, 16384> buffer{};
              for (;;) {
                const auto count = session->read(buffer);
                if (count == 0) break;
                write_frame(message(
                    "terminalOutput", "event", session->id(),
                    "{\"data\":\"" +
                        b64_encode(std::span<const std::uint8_t>(buffer.data(), count)) +
                        "\"}"));
              }
              const int code = session->wait();
              write_frame(message("terminalExit", "event", session->id(),
                                  "{\"exitCode\":" + std::to_string(code) + "}"));
            } catch (const std::exception& error) {
              write_frame(message("error", "event", session->id(),
                                  "{\"message\":\"" + json_escape(error.what()) + "\"}"));
            }
          });
          sessions.emplace(id, std::move(record));
          write_frame(message("terminalOpened", request_id, id, "{}"));
          continue;
        }

        if (type == "terminalInput") {
          auto& record = require_session(sessions, session_id);
          record.session->write(b64_decode(require_string(payload, "data")));
          continue;
        }

        if (type == "terminalResize") {
          auto& record = require_session(sessions, session_id);
          record.session->resize({
              static_cast<std::uint16_t>(optional_int(payload, "columns", 120)),
              static_cast<std::uint16_t>(optional_int(payload, "rows", 32))});
          continue;
        }

        if (type == "terminalInterrupt") {
          require_session(sessions, session_id).session->interrupt();
          continue;
        }

        if (type == "terminalTerminate") {
          require_session(sessions, session_id)
              .session->terminate(optional_bool(payload, "force", false));
          continue;
        }

        if (type == "shutdown") {
          shutting_down = true;
          for (auto& [id, record] : sessions) {
            (void)id;
            try {
              record->session->terminate(true);
            } catch (...) {
            }
          }
          write_frame(message("shutdown", request_id, "", "{}"));
          continue;
        }

        throw std::runtime_error("unsupported native host command: " + type);
      } catch (const std::exception& error) {
        write_frame(message("error", request_id, session_id,
                            "{\"message\":\"" + json_escape(error.what()) + "\"}"));
      }
    }
  } catch (const std::exception& error) {
    std::cerr << "ket_host fatal: " << error.what() << '\n';
    for (auto& [id, record] : sessions) {
      (void)id;
      try {
        record->session->terminate(true);
      } catch (...) {
      }
    }
    sessions.clear();
    return 2;
  }

  for (auto& [id, record] : sessions) {
    (void)id;
    try {
      record->session->terminate(true);
    } catch (...) {
    }
  }
  sessions.clear();
  return 0;
}
