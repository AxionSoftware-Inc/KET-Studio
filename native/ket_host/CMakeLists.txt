cmake_minimum_required(VERSION 3.20)
project(ket_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(ket_host
  src/main.cpp
  src/pty_session.cpp
)

target_include_directories(ket_host PRIVATE src)

if(WIN32)
  target_compile_definitions(ket_host PRIVATE KET_PLATFORM_WINDOWS=1)
elseif(APPLE OR UNIX)
  target_compile_definitions(ket_host PRIVATE KET_PLATFORM_POSIX=1)
endif()

if(MSVC)
  target_compile_options(ket_host PRIVATE /W4 /permissive-)
else()
  target_compile_options(ket_host PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
