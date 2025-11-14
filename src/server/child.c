#include "child.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <signal.h>
#include <errno.h>
#include "../libutils/log.h"

#define BUFFER_SIZE 1024

void handle_child(int client_fd) {
#ifndef NO_ROBUST
    // Story 2.3: Ignore SIGPIPE to prevent child process crash
    signal(SIGPIPE, SIG_IGN);
    COMPILE_TIME_LOG_DEBUG("SIGPIPE ignored in child process\n");

    // Story 2.4: Set socket timeout to defend against Slowloris
    struct timeval tv;
    tv.tv_sec = 5;
    tv.tv_usec = 0;
    setsockopt(client_fd, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof tv);
    COMPILE_TIME_LOG_DEBUG("Socket timeout set to %ld seconds\n", tv.tv_sec);
#endif

    char buffer[BUFFER_SIZE] = {0};
    COMPILE_TIME_LOG_DEBUG("Reading from client (fd: %d)...\n", client_fd);
    int valread = read(client_fd, buffer, BUFFER_SIZE);

    // Story 2.5: I/O Error Checking
    if (valread > 0) {
        COMPILE_TIME_LOG_DEBUG("Read %d bytes from client\n", valread);
        if (strcmp(buffer, "GET_SYS_INFO\n") == 0) {
            log_info("Received GET_SYS_INFO from client\n");
            COMPILE_TIME_LOG_DEBUG("Executing uptime command\n");
            
            // Use popen() to execute command and read output
            FILE *fp = popen("uptime", "r");
            if (fp == NULL) {
                log_info("popen() failed: %s\n", strerror(errno));
                COMPILE_TIME_LOG_DEBUG("Failed to execute uptime command\n");
                close(client_fd);
                exit(EXIT_FAILURE);
            }

            // Read command output
            char output[BUFFER_SIZE];
            size_t bytes_read = fread(output, 1, sizeof(output) - 1, fp);
            int pclose_status = pclose(fp);
            
            if (pclose_status != 0) {
                COMPILE_TIME_LOG_DEBUG("pclose() returned non-zero status: %d\n", pclose_status);
            }

            if (bytes_read > 0) {
                output[bytes_read] = '\0';
                COMPILE_TIME_LOG_DEBUG("Command output (%zu bytes): %s", bytes_read, output);
                
                // Write response to client socket
                // This is where SIGPIPE can be triggered if client disconnected
                ssize_t bytes_written = write(client_fd, output, bytes_read);
                
                if (bytes_written < 0) {
                    // Story 2.5: Handle write errors
                    if (errno == EPIPE) {
                        // This happens when SIGPIPE is ignored (server_good)
                        log_info("write() error: Broken pipe (EPIPE)\n");
                        COMPILE_TIME_LOG_DEBUG("Client disconnected before response sent\n");
                    } else if (errno == ECONNRESET) {
                        log_info("write() error: Connection reset by peer\n");
                        COMPILE_TIME_LOG_DEBUG("write() failed with ECONNRESET\n");
                    } else {
                        log_info("write() error: %s\n", strerror(errno));
                        COMPILE_TIME_LOG_DEBUG("write() failed with errno %d\n", errno);
                    }
                } else if (bytes_written < (ssize_t)bytes_read) {
                    // Partial write - client may have disconnected mid-transfer
                    COMPILE_TIME_LOG_DEBUG("Partial write: %zd of %zu bytes\n", bytes_written, bytes_read);
                    log_info("Partial write to client (possible disconnect)\n");
                } else {
                    // Success
                    COMPILE_TIME_LOG_DEBUG("Successfully wrote %zd bytes to client\n", bytes_written);
                    log_info("Response sent successfully\n");
                }
            } else {
                log_info("No output from command\n");
                COMPILE_TIME_LOG_DEBUG("fread() returned 0 bytes\n");
            }
        } else {
            // Unknown command
            log_info("Unknown command received\n");
            COMPILE_TIME_LOG_DEBUG("Received: %s", buffer);
            const char *error_msg = "ERROR: Unknown command\n";
            write(client_fd, error_msg, strlen(error_msg));
        }
    } else if (valread == 0) {
        // Story 2.5: Normal EOF - client closed connection gracefully
        COMPILE_TIME_LOG_DEBUG("Client closed connection (EOF)\n");
        log_info("Client closed connection\n");
    } else {
        // Story 2.5: Read error - distinguish different error types
        if (errno == ECONNRESET) {
            log_info("Connection reset by peer\n");
            COMPILE_TIME_LOG_DEBUG("read() failed with ECONNRESET\n");
        } else if (errno == ETIMEDOUT || errno == EAGAIN) {
            log_info("Read timeout (client idle too long)\n");
            COMPILE_TIME_LOG_DEBUG("read() failed with timeout: %s\n", strerror(errno));
        } else {
            log_info("Error reading from client: %s\n", strerror(errno));
            COMPILE_TIME_LOG_DEBUG("read() failed with errno %d\n", errno);
        }
    }

    COMPILE_TIME_LOG_DEBUG("Closing client connection (fd: %d)\n", client_fd);
    close(client_fd);
}
