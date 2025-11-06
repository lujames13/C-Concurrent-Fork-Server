#include "child.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <signal.h>
#include "../libutils/log.h"

#define BUFFER_SIZE 1024

void handle_child(int client_fd) {
#ifndef NO_ROBUST
    // Ignore SIGPIPE
    signal(SIGPIPE, SIG_IGN);

    // Set socket timeout
    struct timeval tv;
    tv.tv_sec = 5;
    tv.tv_usec = 0;
    setsockopt(client_fd, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof tv);
#endif

    char buffer[BUFFER_SIZE] = {0};
    int valread = read(client_fd, buffer, BUFFER_SIZE);

    if (valread > 0) {
        if (strcmp(buffer, "GET_SYS_INFO\n") == 0) {
            log_info("Received GET_SYS_INFO from client\n");
            // Redirect stdout to client socket
            dup2(client_fd, STDOUT_FILENO);
            dup2(client_fd, STDERR_FILENO);
            // Execute command
            execlp("uptime", "uptime", (char *)NULL);
            // execlp only returns if there is an error
            perror("execlp");
            exit(EXIT_FAILURE);
        }
    }

    close(client_fd);
}
