#pragma once

#include "pty_session.hpp"

#if defined(KET_PLATFORM_WINDOWS)
namespace ket {
std::unique_ptr<PtySession> create_conpty_session(const LaunchSpec& spec);
}  // namespace ket
#endif
