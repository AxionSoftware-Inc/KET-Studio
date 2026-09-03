#include "pty_session.hpp"

#include <cerrno>
#include <csignal>
#include <cstring>
#include <stdexcept>
#include <string>
#include <utility>

#if defined(KET_PLATFORM_WINDOWS)
#include "conpty_session.hpp"
#endif

#if defined(KET_PLATFORM_POSIX)
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>
#endif

namespace ket {

#if defined(KET_PLATFORM_POSIX)
namespace {

class PosixPtySession final : public PtySession {
 public:
  PosixPtySession(const LaunchSpec& spec, int master_fd, pid_t child_pid)
      : id_("pty-" + std::to_string(child_pid)),
        master_fd_(master_fd),
        child_pid_(child_pid) {
    resize(spec.size);
  }

  ~PosixPtySession() override {
    if (master_fd_ >= 0) ::close(master_fd_);
  }

  [[nodiscard]] std::string id() const override { return id_; }

  std::size_t read(std::span<std::uint8_t> buffer) override {
    for (;;) {
      const auto count = ::read(master_fd_, buffer.data(), buffer.size());
      if (count > 0) return static_cast<std::size_t>(count);
      if (count == 0) return 0;
      if (errno == EINTR) continue;
      if (errno == EIO) return 0;
      throw std::runtime_error(std::string("PTY read failed: ") +
                               std::strerror(errno));
    }
  }

  void write(std::span<const std::uint8_t> bytes) override {
    std::size_t offset = 0;
    while (offset < bytes.size()) {
      const auto written = ::write(master_fd_, bytes.data() + offset,
                                   bytes.size() - offset);
      if (written < 0) {
        if (errno == EINTR) continue;
        throw std::runtime_error(std::string("PTY write failed: ") +
                                 std::strerror(errno));
      }
      offset += static_cast<std::size_t>(written);
    }
  }

  void resize(TerminalSize size) override {
    winsize ws{};
    ws.ws_col = size.columns;
    ws.ws_row = size.rows;
    if (::ioctl(master_fd_, TIOCSWINSZ, &ws) == -1) {
      throw std::runtime_error(std::string("PTY resize failed: ") +
                               std::strerror(errno));
    }
  }

  void interrupt() override {
    if (::kill(-child_pid_, SIGINT) == -1 && errno != ESRCH) {
      throw std::runtime_error(std::string("PTY interrupt failed: ") +
                               std::strerror(errno));
    }
  }

  void terminate(bool force) override {
    const int signal = force ? SIGKILL : SIGTERM;
    if (::kill(-child_pid_, signal) == -1 && errno != ESRCH) {
      throw std::runtime_error(std::string("PTY terminate failed: ") +
                               std::strerror(errno));
    }
  }

  [[nodiscard]] int wait() override {
    int status = 0;
    for (;;) {
      if (::waitpid(child_pid_, &status, 0) >= 0) break;
      if (errno == EINTR) continue;
      throw std::runtime_error(std::string("waitpid failed: ") +
                               std::strerror(errno));
    }
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return -1;
  }

 private:
  std::string id_;
  int master_fd_{-1};
  pid_t child_pid_{-1};
};

std::vector<char*> make_argv(const LaunchSpec& spec,
                             std::vector<std::string>& storage) {
  storage.clear();
  storage.push_back(spec.executable);
  storage.insert(storage.end(), spec.arguments.begin(), spec.arguments.end());

  std::vector<char*> argv;
  argv.reserve(storage.size() + 1);
  for (auto& item : storage) argv.push_back(item.data());
  argv.push_back(nullptr);
  return argv;
}

}  // namespace
#endif

std::unique_ptr<PtySession> create_pty_session(const LaunchSpec& spec) {
  if (spec.executable.empty()) {
    throw std::invalid_argument("PTY executable must not be empty");
  }
  if (spec.size.columns == 0 || spec.size.rows == 0) {
    throw std::invalid_argument("PTY dimensions must be positive");
  }

#if defined(KET_PLATFORM_WINDOWS)
  return create_conpty_session(spec);
#elif defined(KET_PLATFORM_POSIX)
  const int master_fd = ::posix_openpt(O_RDWR | O_NOCTTY | O_CLOEXEC);
  if (master_fd < 0) {
    throw std::runtime_error(std::string("posix_openpt failed: ") +
                             std::strerror(errno));
  }
  if (::grantpt(master_fd) != 0 || ::unlockpt(master_fd) != 0) {
    const auto message = std::string("Failed to prepare PTY: ") +
                         std::strerror(errno);
    ::close(master_fd);
    throw std::runtime_error(message);
  }

  char* slave_name = ::ptsname(master_fd);
  if (slave_name == nullptr) {
    const auto message = std::string("ptsname failed: ") + std::strerror(errno);
    ::close(master_fd);
    throw std::runtime_error(message);
  }

  const pid_t pid = ::fork();
  if (pid < 0) {
    const auto message = std::string("fork failed: ") + std::strerror(errno);
    ::close(master_fd);
    throw std::runtime_error(message);
  }

  if (pid == 0) {
    if (::setsid() < 0) _exit(126);
    const int slave_fd = ::open(slave_name, O_RDWR);
    if (slave_fd < 0) _exit(126);
    if (::ioctl(slave_fd, TIOCSCTTY, 0) < 0) _exit(126);

    ::dup2(slave_fd, STDIN_FILENO);
    ::dup2(slave_fd, STDOUT_FILENO);
    ::dup2(slave_fd, STDERR_FILENO);
    if (slave_fd > STDERR_FILENO) ::close(slave_fd);
    ::close(master_fd);

    if (!spec.working_directory.empty() &&
        ::chdir(spec.working_directory.c_str()) != 0) {
      _exit(126);
    }

    for (const auto& [key, value] : spec.environment) {
      if (::setenv(key.c_str(), value.c_str(), 1) != 0) _exit(126);
    }

    std::vector<std::string> storage;
    auto argv = make_argv(spec, storage);
    ::execvp(spec.executable.c_str(), argv.data());
    _exit(errno == ENOENT ? 127 : 126);
  }

  return std::make_unique<PosixPtySession>(spec, master_fd, pid);
#else
  (void)spec;
  throw std::runtime_error("No PTY backend compiled for this platform.");
#endif
}

}  // namespace ket
