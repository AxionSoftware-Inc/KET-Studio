#include "json_value.hpp"

#include <cctype>
#include <cstdlib>
#include <string>
#include <utility>

namespace ket::json {
namespace {

void append_utf8(std::string& out, std::uint32_t codepoint) {
  if (codepoint <= 0x7F) {
    out.push_back(static_cast<char>(codepoint));
  } else if (codepoint <= 0x7FF) {
    out.push_back(static_cast<char>(0xC0 | (codepoint >> 6)));
    out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
  } else if (codepoint <= 0xFFFF) {
    out.push_back(static_cast<char>(0xE0 | (codepoint >> 12)));
    out.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
    out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
  } else {
    out.push_back(static_cast<char>(0xF0 | (codepoint >> 18)));
    out.push_back(static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F)));
    out.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
    out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
  }
}

class Parser final {
 public:
  explicit Parser(std::string_view source) : source_(source) {}

  Value parse_document() {
    skip_ws();
    auto value = parse_value();
    skip_ws();
    if (!eof()) fail("unexpected trailing data");
    return value;
  }

 private:
  std::string_view source_;
  std::size_t pos_{0};

  [[nodiscard]] bool eof() const noexcept { return pos_ >= source_.size(); }
  [[nodiscard]] char peek() const { return eof() ? '\0' : source_[pos_]; }

  char take() {
    if (eof()) fail("unexpected end of input");
    return source_[pos_++];
  }

  [[noreturn]] void fail(const std::string& message) const {
    throw ParseError(message + " at byte " + std::to_string(pos_));
  }

  void skip_ws() {
    while (!eof()) {
      const unsigned char ch = static_cast<unsigned char>(source_[pos_]);
      if (!std::isspace(ch)) break;
      ++pos_;
    }
  }

  bool consume(char expected) {
    skip_ws();
    if (peek() != expected) return false;
    ++pos_;
    return true;
  }

  void expect(char expected) {
    skip_ws();
    if (take() != expected) fail(std::string("expected '") + expected + "'");
  }

  Value parse_value() {
    skip_ws();
    switch (peek()) {
      case '{': return Value(parse_object());
      case '[': return Value(parse_array());
      case '"': return Value(parse_string());
      case 't': consume_literal("true"); return Value(true);
      case 'f': consume_literal("false"); return Value(false);
      case 'n': consume_literal("null"); return Value(nullptr);
      default:
        if (peek() == '-' || (peek() >= '0' && peek() <= '9')) {
          return Value(parse_number());
        }
        fail("unexpected token");
    }
  }

  Value::Object parse_object() {
    expect('{');
    Value::Object object;
    skip_ws();
    if (consume('}')) return object;

    for (;;) {
      skip_ws();
      if (peek() != '"') fail("object key must be a string");
      auto key = parse_string();
      expect(':');
      auto [it, inserted] = object.emplace(std::move(key), parse_value());
      if (!inserted) fail("duplicate object key");
      skip_ws();
      if (consume('}')) break;
      expect(',');
    }
    return object;
  }

  Value::Array parse_array() {
    expect('[');
    Value::Array array;
    skip_ws();
    if (consume(']')) return array;

    for (;;) {
      array.push_back(parse_value());
      skip_ws();
      if (consume(']')) break;
      expect(',');
    }
    return array;
  }

  static int hex_value(char ch) {
    if (ch >= '0' && ch <= '9') return ch - '0';
    if (ch >= 'a' && ch <= 'f') return ch - 'a' + 10;
    if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10;
    return -1;
  }

  std::uint32_t parse_hex4() {
    std::uint32_t value = 0;
    for (int i = 0; i < 4; ++i) {
      const int digit = hex_value(take());
      if (digit < 0) fail("invalid unicode escape");
      value = (value << 4) | static_cast<std::uint32_t>(digit);
    }
    return value;
  }

  std::string parse_string() {
    expect('"');
    std::string out;
    while (!eof()) {
      const char ch = take();
      if (ch == '"') return out;
      if (static_cast<unsigned char>(ch) < 0x20) fail("control character in string");
      if (ch != '\\') {
        out.push_back(ch);
        continue;
      }

      const char escape = take();
      switch (escape) {
        case '"': out.push_back('"'); break;
        case '\\': out.push_back('\\'); break;
        case '/': out.push_back('/'); break;
        case 'b': out.push_back('\b'); break;
        case 'f': out.push_back('\f'); break;
        case 'n': out.push_back('\n'); break;
        case 'r': out.push_back('\r'); break;
        case 't': out.push_back('\t'); break;
        case 'u': {
          std::uint32_t cp = parse_hex4();
          if (cp >= 0xD800 && cp <= 0xDBFF) {
            if (take() != '\\' || take() != 'u') fail("invalid unicode surrogate pair");
            const std::uint32_t low = parse_hex4();
            if (low < 0xDC00 || low > 0xDFFF) fail("invalid unicode low surrogate");
            cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
          } else if (cp >= 0xDC00 && cp <= 0xDFFF) {
            fail("unexpected unicode low surrogate");
          }
          append_utf8(out, cp);
          break;
        }
        default: fail("invalid string escape");
      }
    }
    fail("unterminated string");
  }

  double parse_number() {
    skip_ws();
    const std::size_t start = pos_;
    if (peek() == '-') ++pos_;
    if (peek() == '0') {
      ++pos_;
    } else {
      if (peek() < '1' || peek() > '9') fail("invalid number");
      while (peek() >= '0' && peek() <= '9') ++pos_;
    }
    if (peek() == '.') {
      ++pos_;
      if (peek() < '0' || peek() > '9') fail("invalid fraction");
      while (peek() >= '0' && peek() <= '9') ++pos_;
    }
    if (peek() == 'e' || peek() == 'E') {
      ++pos_;
      if (peek() == '+' || peek() == '-') ++pos_;
      if (peek() < '0' || peek() > '9') fail("invalid exponent");
      while (peek() >= '0' && peek() <= '9') ++pos_;
    }

    const std::string token(source_.substr(start, pos_ - start));
    char* end = nullptr;
    const double value = std::strtod(token.c_str(), &end);
    if (end == nullptr || *end != '\0') fail("invalid number");
    return value;
  }

  void consume_literal(std::string_view literal) {
    if (source_.substr(pos_, literal.size()) != literal) fail("invalid literal");
    pos_ += literal.size();
  }
};

}  // namespace

bool Value::as_bool() const { return std::get<bool>(storage_); }
double Value::as_number() const { return std::get<double>(storage_); }
const std::string& Value::as_string() const { return std::get<std::string>(storage_); }
const Value::Array& Value::as_array() const { return std::get<Array>(storage_); }
const Value::Object& Value::as_object() const { return std::get<Object>(storage_); }

const Value* Value::find(std::string_view key) const noexcept {
  if (!is_object()) return nullptr;
  const auto& object = std::get<Object>(storage_);
  const auto it = object.find(std::string(key));
  return it == object.end() ? nullptr : &it->second;
}

const Value& Value::at(std::string_view key) const {
  const auto* value = find(key);
  if (value == nullptr) throw std::out_of_range("missing JSON key: " + std::string(key));
  return *value;
}

Value parse(std::string_view source) { return Parser(source).parse_document(); }

}  // namespace ket::json
