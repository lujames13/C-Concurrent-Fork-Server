#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>
#include "../libutils/log.h"
#include "child.h"
#include "signal.h"

#define MAX_CONNECTIONS 10

int main(int argc, char *argv[]) {
    int server_fd, client_fd;
    struct sockaddr_in address;
    int opt = 1;
    int addrlen = sizeof(address);
    int port;

    // Story 1.3: Read port from command line arguments
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    port = atoi(argv[1]);
    if (port <= 0 || port > 65535) {
        fprintf(stderr, "Invalid port number: %s\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    log_init(LOG_LEVEL_INFO);

#ifndef NO_ROBUST
    setup_sigchld_handler();
#endif

    // Story 1.3: Create socket
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }

    // Story 1.3: Set socket options (SO_REUSEADDR)
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt))) {
        perror("setsockopt");
        exit(EXIT_FAILURE);
    }

    // Story 1.3: Bind to port
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }

    // Story 1.3: Listen for connections
    if (listen(server_fd, MAX_CONNECTIONS) < 0) {
        perror("listen");
        exit(EXIT_FAILURE);
    }

    log_info("Server listening on port %d\n", port);

    // Story 1.3: Accept connections in infinite loop
    while (1) {
        if ((client_fd = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen)) < 0) {
            perror("accept");
            continue; // Continue to accept other connections
        }

        // Story 1.4: fork() will be added here
        pid_t pid = fork();

        if (pid == -1) {
#ifndef NO_ROBUST
            log_info("fork() failed: %s\n", strerror(errno));
            write(client_fd, "SERVER_BUSY\n", 14);
            close(client_fd);
            sleep(1);
#else
            perror("fork");
            close(client_fd);
#endif
        } else if (pid == 0) {
            // Child process
            close(server_fd); // Child doesn't need the listener
            handle_child(client_fd);
            exit(0);
        } else {
            // Parent process
            close(client_fd); // Parent doesn't need this connection
        }
    }

    return 0;
}
