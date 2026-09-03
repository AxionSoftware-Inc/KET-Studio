#include "conpty_session.hpp"

#if defined(KET_PLATFORM_WINDOWS)

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <atomic>
#include <map>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace ket {
namespace {

std::runtime_error win_error(const char* operation) {
  return std::runtime_error(std::string(operation) + " failed with Win32 error " +
                            std::to_string(GetLastError()));
}

std::wstring widen(const std::string& value) {
  if (value.empty()) return {};
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                                        static_cast<int>(value.size()), nullptr, 0);
  if (count <= 0) throw win_error("MultiByteToWideChar");
  std::wstring result(static_cast<std::size_t>(count), L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), result.data(), count) != count) {
    throw win_error("MultiByteToWideChar");
  }
  return result;
}

std::wstring quote_argument(const std::wstring& argument) {
  if (argument.empty()) return L"\"\"";
  if (argument.find_first_of(L" \t\n\v\"") == std::wstring::npos) return argument;

  std::wstring result = L"\"";
  std::size_t slashes = 0;
  for (const wchar_t ch : argument) {
    if (ch == L'\\') {
      ++slashes;
      continue;
    }
    if (ch == L'\"') {
      result.append(slashes * 2 + 1, L'\\');
      result.push_back(L'\"');
      slashes = 0;
      continue;
    }
    result.append(slashes, L'\\');
    slashes = 0;
    result.push_back(ch);
  }
  result.append(slashes * 2, L'\\');
  result.push_back(L'\"');
  return result;
}

std::wstring build_command_line(const LaunchSpec& spec) {
  std::wstring command = quote_argument(widen(spec.executable));
  for (const auto& argument : spec.arguments) {
    command.push_back(L' ');
    command += quote_argument(widen(argument));
  }
  return command;
}

std::vector<wchar_t> build_environment_block(
    const std::map<std::string, std::string>& overrides) {
  if (overrides.empty()) return {};

  std::map<std::wstring, std::wstring> environment;
  LPWCH block = GetEnvironmentStringsW();
  if (block == nullptr) throw win_error("GetEnvironmentStringsW");
  for (const wchar_t* cursor = block; *cursor != L'\0';) {
    std::wstring entry(cursor);
    cursor += entry.size() + 1;
    const auto equals = entry.find(L'=', entry.starts_with(L'=') ? 1 : 0);
    if (equals == std::wstring::npos) continue;
    environment[entry.substr(0, equals)] = entry.substr(equals + 1);
  }
  FreeEnvironmentStringsW(block);

  for (const auto& [key, value] : overrides) {
    environment[widen(key)] = widen(value);
  }

  std::vector<wchar_t> result;
  for (const auto& [key, value] : environment) {
    const std::wstring entry = key + L"=" + value;
    result.insert(result.end(), entry.begin(), entry.end());
    result.push_back(L'\0');
  }
  result.push_back(L'\0');
  return result;
}

class ConPtySession final : public PtySession {
 public:
  ConPtySession(HPCON pseudo_console, HANDLE input_write, HANDLE output_read,
                HANDLE process, HANDLE job, DWORD process_id)
      : pseudo_console_(pseudo_console),
        input_write_(input_write),
        output_read_(output_read),
        process_(process),
        job_(job),
        id_("conpty-" + std::to_string(process_id)) {}

  ~ConPtySession() override {
    if (input_write_ != nullptr) CloseHandle(input_write_);
    if (output_read_ != nullptr) CloseHandle(output_read_);
    if (process_ != nullptr) CloseHandle(process_);
    if (pseudo_console_ != nullptr) ClosePseudoConsole(pseudo_console_);
    if (job_ != nullptr) CloseHandle(job_);
  }

  [[nodiscard]] std::string id() const override { return id_; }

  std::size_t read(std::span<std::uint8_t> buffer) override {
    DWORD count = 0;
    if (!ReadFile(output_read_, buffer.data(), static_cast<DWORD>(buffer.size()),
                  &count, nullptr)) {
      const DWORD error = GetLastError();
      if (error == ERROR_BROKEN_PIPE || error == ERROR_NO_DATA) return 0;
      throw win_error("ConPTY ReadFile");
    }
    return static_cast<std::size_t>(count);
  }

  void write(std::span<const std::uint8_t> bytes) override {
    std::size_t offset = 0;
    while (offset < bytes.size()) {
      DWORD written = 0;
      const auto remaining = static_cast<DWORD>(bytes.size() - offset);
      if (!WriteFile(input_write_, bytes.data() + offset, remaining, &written,
                     nullptr)) {
        throw win_error("ConPTY WriteFile");
      }
      offset += static_cast<std::size_t>(written);
    }
  }

  void resize(TerminalSize size) override {
    const COORD dimensions{static_cast<SHORT>(size.columns),
                           static_cast<SHORT>(size.rows)};
    const HRESULT result = ResizePseudoConsole(pseudo_console_, dimensions);
    if (FAILED(result)) {
      throw std::runtime_error("ResizePseudoConsole failed with HRESULT " +
                               std::to_string(static_cast<long>(result)));
    }
  }

  void interrupt() override {
    const std::uint8_t ctrl_c = 0x03;
    write(std::span<const std::uint8_t>(&ctrl_c, 1));
  }

  void terminate(bool force) override {
    if (!force) {
      interrupt();
      return;
    }
    if (!TerminateJobObject(job_, 1)) {
      const DWORD error = GetLastError();
      if (error != ERROR_ACCESS_DENIED) throw win_error("TerminateJobObject");
    }
  }

  [[nodiscard]] int wait() override {
    if (WaitForSingleObject(process_, INFINITE) != WAIT_OBJECT_0) {
      throw win_error("WaitForSingleObject");
    }
    DWORD code = 0;
    if (!GetExitCodeProcess(process_, &code)) throw win_error("GetExitCodeProcess");
    return static_cast<int>(code);
  }

 private:
  HPCON pseudo_console_{nullptr};
  HANDLE input_write_{nullptr};
  HANDLE output_read_{nullptr};
  HANDLE process_{nullptr};
  HANDLE job_{nullptr};
  std::string id_;
};

}  // namespace

std::unique_ptr<PtySession> create_conpty_session(const LaunchSpec& spec) {
  HANDLE input_read = nullptr;
  HANDLE input_write = nullptr;
  HANDLE output_read = nullptr;
  HANDLE output_write = nullptr;
  HPCON pseudo_console = nullptr;
  HANDLE job = nullptr;
  PROCESS_INFORMATION process_info{};

  auto cleanup = [&]() {
    if (input_read != nullptr) CloseHandle(input_read);
    if (input_write != nullptr) CloseHandle(input_write);
    if (output_read != nullptr) CloseHandle(output_read);
    if (output_write != nullptr) CloseHandle(output_write);
    if (process_info.hThread != nullptr) CloseHandle(process_info.hThread);
    if (process_info.hProcess != nullptr) CloseHandle(process_info.hProcess);
    if (pseudo_console != nullptr) ClosePseudoConsole(pseudo_console);
    if (job != nullptr) CloseHandle(job);
  };

  if (!CreatePipe(&input_read, &input_write, nullptr, 0) ||
      !CreatePipe(&output_read, &output_write, nullptr, 0)) {
    cleanup();
    throw win_error("CreatePipe");
  }

  const COORD dimensions{static_cast<SHORT>(spec.size.columns),
                         static_cast<SHORT>(spec.size.rows)};
  const HRESULT pseudo_result =
      CreatePseudoConsole(dimensions, input_read, output_write, 0, &pseudo_console);
  if (FAILED(pseudo_result)) {
    cleanup();
    throw std::runtime_error("CreatePseudoConsole failed with HRESULT " +
                             std::to_string(static_cast<long>(pseudo_result)));
  }
  CloseHandle(input_read);
  input_read = nullptr;
  CloseHandle(output_write);
  output_write = nullptr;

  SIZE_T attribute_bytes = 0;
  InitializeProcThreadAttributeList(nullptr, 1, 0, &attribute_bytes);
  std::vector<std::byte> attribute_storage(attribute_bytes);
  auto* attributes = reinterpret_cast<PPROC_THREAD_ATTRIBUTE_LIST>(
      attribute_storage.data());
  if (!InitializeProcThreadAttributeList(attributes, 1, 0, &attribute_bytes)) {
    cleanup();
    throw win_error("InitializeProcThreadAttributeList");
  }
  if (!UpdateProcThreadAttribute(attributes, 0,
                                 PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                                 pseudo_console, sizeof(pseudo_console), nullptr,
                                 nullptr)) {
    DeleteProcThreadAttributeList(attributes);
    cleanup();
    throw win_error("UpdateProcThreadAttribute");
  }

  STARTUPINFOEXW startup{};
  startup.StartupInfo.cb = sizeof(startup);
  startup.lpAttributeList = attributes;

  auto command = build_command_line(spec);
  std::vector<wchar_t> mutable_command(command.begin(), command.end());
  mutable_command.push_back(L'\0');
  const auto executable = widen(spec.executable);
  const auto working_directory = widen(spec.working_directory);
  auto environment = build_environment_block(spec.environment);

  job = CreateJobObjectW(nullptr, nullptr);
  if (job == nullptr) {
    DeleteProcThreadAttributeList(attributes);
    cleanup();
    throw win_error("CreateJobObjectW");
  }
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION job_info{};
  job_info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &job_info,
                               sizeof(job_info))) {
    DeleteProcThreadAttributeList(attributes);
    cleanup();
    throw win_error("SetInformationJobObject");
  }

  const DWORD flags = EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT |
                      CREATE_SUSPENDED;
  if (!CreateProcessW(executable.c_str(), mutable_command.data(), nullptr, nullptr,
                      FALSE, flags,
                      environment.empty() ? nullptr : environment.data(),
                      working_directory.empty() ? nullptr : working_directory.c_str(),
                      &startup.StartupInfo, &process_info)) {
    DeleteProcThreadAttributeList(attributes);
    cleanup();
    throw win_error("CreateProcessW");
  }
  DeleteProcThreadAttributeList(attributes);

  if (!AssignProcessToJobObject(job, process_info.hProcess)) {
    TerminateProcess(process_info.hProcess, 1);
    cleanup();
    throw win_error("AssignProcessToJobObject");
  }
  if (ResumeThread(process_info.hThread) == static_cast<DWORD>(-1)) {
    TerminateJobObject(job, 1);
    cleanup();
    throw win_error("ResumeThread");
  }

  CloseHandle(process_info.hThread);
  process_info.hThread = nullptr;

  auto result = std::make_unique<ConPtySession>(
      pseudo_console, input_write, output_read, process_info.hProcess, job,
      process_info.dwProcessId);

  pseudo_console = nullptr;
  input_write = nullptr;
  output_read = nullptr;
  process_info.hProcess = nullptr;
  job = nullptr;
  return result;
}

}  // namespace ket

#endif
