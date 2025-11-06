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
    // Ignore SIGPIPE
    signal(SIGPIPE, SIG_IGN);
    COMPILE_TIME_LOG_DEBUG("SIGPIPE ignored in child process\n");

    // Set socket timeout
    struct timeval tv;
    tv.tv_sec = 5;
    tv.tv_usec = 0;
    setsockopt(client_fd, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof tv);
    COMPILE_TIME_LOG_DEBUG("Socket timeout set to %ld seconds\n", tv.tv_sec);
#endif

    char buffer[BUFFER_SIZE] = {0};
    COMPILE_TIME_LOG_DEBUG("Reading from client (fd: %d)...\n", client_fd);
    int valread = read(client_fd, buffer, BUFFER_SIZE);

    if (valread > 0) {
        COMPILE_TIME_LOG_DEBUG("Read %d bytes from client\n", valread);
        if (strcmp(buffer, "GET_SYS_INFO\n") == 0) {
            log_info("Received GET_SYS_INFO from client\n");
            COMPILE_TIME_LOG_DEBUG("Executing uptime command\n");
            // Redirect stdout to client socket
            dup2(client_fd, STDOUT_FILENO);
            dup2(client_fd, STDERR_FILENO);
            // Execute command
            execlp("uptime", "uptime", (char *)NULL);
            // execlp only returns if there is an error
            perror("execlp");
            exit(EXIT_FAILURE);
        }
    } else if (valread == 0) {
        log_info("Client closed connection\n");
    } else {
        log_info("Error reading from client: %s\n", strerror(errno));
    }

    COMPILE_TIME_LOG_DEBUG("Closing client connection (fd: %d)\n", client_fd);
    close(client_fd);
}
