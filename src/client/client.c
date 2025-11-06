#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "../libutils/log.h"

#define BUFFER_SIZE 1024

int main(int argc, char const *argv[]) {
    int sock = 0;
    struct sockaddr_in serv_addr;
    char buffer[BUFFER_SIZE] = {0};
    int debug_mode = 0;

    // Story 1.7: Parse -d flag for debug mode
    int arg_index = 1;
    if (argc >= 2 && strcmp(argv[1], "-d") == 0) {
        debug_mode = 1;
        arg_index = 2;
    }

    // Story 1.5: Parse command-line arguments (IP and Port)
    if (argc < arg_index + 2) {
        fprintf(stderr, "Usage: %s [-d] <server_ip> <port>\n", argv[0]);
        fprintf(stderr, "Example: %s 127.0.0.1 8080\n", argv[0]);
        fprintf(stderr, "Example: %s -d 127.0.0.1 8080\n", argv[0]);
        return 1;
    }

    const char *server_ip = argv[arg_index];
    int port = atoi(argv[arg_index + 1]);

    if (port <= 0 || port > 65535) {
        fprintf(stderr, "Error: Invalid port number %d\n", port);
        return 1;
    }

    // Story 1.7: Initialize log system with appropriate level
    log_init(debug_mode ? LOG_LEVEL_DEBUG : LOG_LEVEL_INFO);

    COMPILE_TIME_LOG_DEBUG("Creating socket...\n");
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("Socket creation error");
        return -1;
    }
    COMPILE_TIME_LOG_DEBUG("Socket created successfully (fd: %d)\n", sock);

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);

    // Convert IPv4 and IPv6 addresses from text to binary form
    if(inet_pton(AF_INET, server_ip, &serv_addr.sin_addr)<=0) {
        fprintf(stderr, "Invalid address / Address not supported: %s\n", server_ip);
        return -1;
    }

    COMPILE_TIME_LOG_DEBUG("Connecting to %s:%d...\n", server_ip, port);
    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        perror("Connection Failed");
        return -1;
    }

    log_info("Connected to server %s:%d\n", server_ip, port);
    printf("Connected to server %s:%d\n", server_ip, port);

    char *message = "GET_SYS_INFO\n";
    COMPILE_TIME_LOG_DEBUG("Sending message: %s", message);
    write(sock, message, strlen(message));
    log_info("GET_SYS_INFO message sent\n");

    COMPILE_TIME_LOG_DEBUG("Waiting for response from server...\n");
    int valread = read(sock, buffer, BUFFER_SIZE);
    if (valread > 0) {
        COMPILE_TIME_LOG_DEBUG("Received %d bytes from server\n", valread);
        printf("%s\n",buffer);
    } else if (valread == 0) {
        log_info("Server closed connection\n");
    } else {
        log_info("Error reading from server\n");
    }

    COMPILE_TIME_LOG_DEBUG("Closing connection\n");
    close(sock);
    return 0;
}
