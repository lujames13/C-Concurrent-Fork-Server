cmake_minimum_required(VERSION 3.10)
project(NetworkMidterm C)

# Set C standard to C11
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

# --- 1. Shared Library: libutils.so ---
# This library will contain the logging system (log.c)
# Will be uncommented in Story 1.2 when log.c is created
# add_library(utils SHARED src/libutils/log.c)
# target_include_directories(utils PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src/libutils)

# --- 2. Server (Good version) - server_good ---
# Will be uncommented in Epic 2 when all robustness mechanisms are implemented
# add_executable(server_good
#     src/server/server.c
#     src/server/child.c
#     src/server/signal.c
# )
# target_link_libraries(server_good utils)

# --- 3. Server (Bad version) - server_bad ---
# Will be uncommented in Story 1.3+ when server.c is created
# add_executable(server_bad
#     src/server/server.c
#     src/server/child.c
#     src/server/signal.c
# )
# target_compile_definitions(server_bad PRIVATE NO_ROBUST)
# target_link_libraries(server_bad utils)

# --- 4. Client ---
# Will be uncommented in Story 1.5 when client.c is created
# add_executable(client
#     src/client/client.c
# )
# target_link_libraries(client utils)

# Note: Subdirectories for libutils, server, and client are prepared.
# Build targets will be uncommented as source files are created in subsequent stories.
