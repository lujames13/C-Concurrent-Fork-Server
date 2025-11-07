cmake_minimum_required(VERSION 3.10)
project(NetworkMidterm C)

# Set C standard to C11
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

# Set RPATH for executables to find libutils.so at runtime
set(CMAKE_INSTALL_RPATH "${CMAKE_BINARY_DIR}")
set(CMAKE_BUILD_RPATH "${CMAKE_BINARY_DIR}")

# --- 1. Shared Library: libutils.so ---
# This library will contain the logging system (log.c)
add_library(utils SHARED src/libutils/log.c)
target_include_directories(utils PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src/libutils)

# --- 2. Server (Good version) - server_good ---
# Story 2.6: Enable server_good build target with all robustness mechanisms
add_executable(server_good
    src/server/server.c
    src/server/child.c
    src/server/signal.c
)
target_link_libraries(server_good utils)

# --- 3. Server (Bad version) - server_bad ---
# Story 1.3: Enable server_bad build target
add_executable(server_bad
    src/server/server.c
    src/server/child.c
    src/server/signal.c
)
target_compile_definitions(server_bad PRIVATE NO_ROBUST)
target_link_libraries(server_bad utils)

# --- 4. Client ---
# Story 1.5: Client build target enabled
add_executable(client
    src/client/client.c
)
target_link_libraries(client utils)

# --- 5. Client (Release with NDEBUG) ---
# Story 1.7: Test NDEBUG compilation
add_executable(client_release
    src/client/client.c
)
target_compile_definitions(client_release PRIVATE NDEBUG)
target_link_libraries(client_release utils)

# Note: Subdirectories for libutils, server, and client are prepared.
# Build targets will be uncommented as source files are created in subsequent stories.
