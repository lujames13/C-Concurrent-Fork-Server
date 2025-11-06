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

    // Story 1.5: Parse command-line arguments (IP and Port)
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <server_ip> <port>\n", argv[0]);
        fprintf(stderr, "Example: %s 127.0.0.1 8080\n", argv[0]);
        return 1;
    }

    const char *server_ip = argv[1];
    int port = atoi(argv[2]);

    if (port <= 0 || port > 65535) {
        fprintf(stderr, "Error: Invalid port number %d\n", port);
        return 1;
    }

    log_init(LOG_LEVEL_INFO);

    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("Socket creation error");
        return -1;
    }

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);

    // Convert IPv4 and IPv6 addresses from text to binary form
    if(inet_pton(AF_INET, server_ip, &serv_addr.sin_addr)<=0) {
        fprintf(stderr, "Invalid address / Address not supported: %s\n", server_ip);
        return -1;
    }

    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        perror("Connection Failed");
        return -1;
    }

    printf("Connected to server %s:%d\n", server_ip, port);

    char *message = "GET_SYS_INFO\n";
    write(sock, message, strlen(message));
    log_info("GET_SYS_INFO message sent\n");

    int valread = read(sock, buffer, BUFFER_SIZE);
    if (valread > 0) {
        printf("%s\n",buffer);
    }

    close(sock);
    return 0;
}
