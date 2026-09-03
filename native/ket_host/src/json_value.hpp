#pragma once

#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <variant>
#include <vector>

namespace ket::json {

class ParseError final : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

class Value {
 public:
  using Array = std::vector<Value>;
  using Object = std::unordered_map<std::string, Value>;
  using Storage = std::variant<std::nullptr_t, bool, double, std::string, Array, Object>;

  Value() : storage_(nullptr) {}
  explicit Value(std::nullptr_t) : storage_(nullptr) {}
  explicit Value(bool value) : storage_(value) {}
  explicit Value(double value) : storage_(value) {}
  explicit Value(std::string value) : storage_(std::move(value)) {}
  explicit Value(Array value) : storage_(std::move(value)) {}
  explicit Value(Object value) : storage_(std::move(value)) {}

  [[nodiscard]] bool is_null() const noexcept { return std::holds_alternative<std::nullptr_t>(storage_); }
  [[nodiscard]] bool is_bool() const noexcept { return std::holds_alternative<bool>(storage_); }
  [[nodiscard]] bool is_number() const noexcept { return std::holds_alternative<double>(storage_); }
  [[nodiscard]] bool is_string() const noexcept { return std::holds_alternative<std::string>(storage_); }
  [[nodiscard]] bool is_array() const noexcept { return std::holds_alternative<Array>(storage_); }
  [[nodiscard]] bool is_object() const noexcept { return std::holds_alternative<Object>(storage_); }

  [[nodiscard]] bool as_bool() const;
  [[nodiscard]] double as_number() const;
  [[nodiscard]] const std::string& as_string() const;
  [[nodiscard]] const Array& as_array() const;
  [[nodiscard]] const Object& as_object() const;

  [[nodiscard]] const Value* find(std::string_view key) const noexcept;
  [[nodiscard]] const Value& at(std::string_view key) const;

 private:
  Storage storage_;
};

[[nodiscard]] Value parse(std::string_view source);

}  // namespace ket::json
