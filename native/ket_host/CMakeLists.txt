cmake_minimum_required(VERSION 3.20)
project(ket_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(KET_HOST_SOURCES
  src/main.cpp
  src/json_value.cpp
  src/pty_session.cpp
)

if(WIN32)
  list(APPEND KET_HOST_SOURCES src/conpty_session.cpp)
endif()

add_executable(ket_host ${KET_HOST_SOURCES})
target_include_directories(ket_host PRIVATE src)

if(WIN32)
  target_compile_definitions(ket_host PRIVATE
    KET_PLATFORM_WINDOWS=1
    WIN32_LEAN_AND_MEAN
    NOMINMAX
    _WIN32_WINNT=0x0A00
  )
elseif(APPLE OR UNIX)
  target_compile_definitions(ket_host PRIVATE KET_PLATFORM_POSIX=1)
endif()

if(MSVC)
  target_compile_options(ket_host PRIVATE /W4 /permissive- /EHsc)
else()
  target_compile_options(ket_host PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
