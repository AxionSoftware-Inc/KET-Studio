#pragma once

#include <cstdint>
#include <memory>
#include <span>
#include <string>
#include <vector>

namespace ket {

struct TerminalSize {
  std::uint16_t columns{120};
  std::uint16_t rows{32};
};

struct LaunchSpec {
  std::string executable;
  std::vector<std::string> arguments;
  std::string working_directory;
  TerminalSize size;
};

class PtySession {
 public:
  virtual ~PtySession() = default;

  [[nodiscard]] virtual std::string id() const = 0;
  virtual void write(std::span<const std::uint8_t> bytes) = 0;
  virtual void resize(TerminalSize size) = 0;
  virtual void interrupt() = 0;
  virtual void terminate(bool force) = 0;
  [[nodiscard]] virtual int wait() = 0;
};

std::unique_ptr<PtySession> create_pty_session(const LaunchSpec& spec);

}  // namespace ket
