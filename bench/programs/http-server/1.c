// A minimal HTTP/1.1 server (one thread per connection) and a pool of keep-alive clients, all on POSIX sockets.
// Each client POSTs {"value": i}; the server answers with the value, and the client sums the answers.
#define _GNU_SOURCE
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define CLIENTS 32

static int port;
static int total;
static atomic_int next_value = 1;
static atomic_long sum;

// Reads one request or response: headers, then Content-Length bytes of body. Returns the body length or -1.
static int read_message(int fd, char *buffer, size_t capacity, char **body) {
    size_t used = 0;
    for (;;) {
        buffer[used] = '\0';
        char *end = strstr(buffer, "\r\n\r\n");
        if (end) {
            char *header = strcasestr(buffer, "content-length:");
            int length = header && header < end ? atoi(header + 15) : 0;
            size_t need = (size_t)(end + 4 - buffer) + (size_t)length;
            while (used < need) {
                ssize_t got = read(fd, buffer + used, capacity - 1 - used);
                if (got <= 0) return -1;
                used += (size_t)got;
            }
            *body = end + 4;
            (*body)[length] = '\0';
            return length;
        }
        if (used == capacity - 1) return -1;
        ssize_t got = read(fd, buffer + used, capacity - 1 - used);
        if (got <= 0) return -1;
        used += (size_t)got;
    }
}

static int write_all(int fd, const char *data, size_t length) {
    while (length > 0) {
        ssize_t sent = write(fd, data, length);
        if (sent <= 0) return -1;
        data += sent;
        length -= (size_t)sent;
    }
    return 0;
}

static void *serve_connection(void *arg) {
    int fd = (int)(long)arg;
    char buffer[4096], response[128], *body;
    while (read_message(fd, buffer, sizeof buffer, &body) >= 0) {
        char *field = strstr(body, "\"value\"");
        long value = field ? strtol(strchr(field + 7, ':') + 1, NULL, 10) : 0;
        char text[32];
        int text_length = snprintf(text, sizeof text, "%ld", value);
        int length = snprintf(response, sizeof response, "HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n%s", text_length, text);
        if (write_all(fd, response, (size_t)length) < 0) break;
    }
    close(fd);
    return NULL;
}

static void *serve(void *arg) {
    int listener = (int)(long)arg;
    for (;;) {
        int fd = accept(listener, NULL, NULL);
        if (fd < 0) continue;
        pthread_t thread;
        pthread_create(&thread, NULL, serve_connection, (void *)(long)fd);
        pthread_detach(thread);
    }
    return NULL;
}

static int connect_server(void) {
    struct sockaddr_in address = {.sin_family = AF_INET, .sin_port = htons((uint16_t)port)};
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    for (;;) {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (connect(fd, (struct sockaddr *)&address, sizeof address) == 0) {
            int on = 1;
            setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &on, sizeof on);
            return fd;
        }
        close(fd);
        usleep(1000);
    }
}

static void *client(void *arg) {
    (void)arg;
    int fd = connect_server();
    char request[256], buffer[4096], *body;
    for (int value; (value = atomic_fetch_add(&next_value, 1)) <= total;) {
        char payload[64];
        int payload_length = snprintf(payload, sizeof payload, "{\"value\":%d}", value);
        int length = snprintf(request, sizeof request,
                              "POST / HTTP/1.1\r\nHost: localhost:%d\r\nContent-Type: application/json\r\n"
                              "Content-Length: %d\r\n\r\n%s",
                              port, payload_length, payload);
        while (write_all(fd, request, (size_t)length) < 0 || read_message(fd, buffer, sizeof buffer, &body) < 0) {
            close(fd);
            fd = connect_server();
        }
        atomic_fetch_add(&sum, atol(body));
    }
    close(fd);
    return NULL;
}

int main(int argc, char **argv) {
    total = argc > 1 ? atoi(argv[1]) : 10;
    srand((unsigned)time(NULL) ^ (unsigned)getpid());
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    int on = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
    struct sockaddr_in address = {.sin_family = AF_INET};
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    do {
        port = 20000 + rand() % 30000;
        address.sin_port = htons((uint16_t)port);
    } while (bind(listener, (struct sockaddr *)&address, sizeof address) != 0);
    listen(listener, 512);

    pthread_t server;
    pthread_create(&server, NULL, serve, (void *)(long)listener);

    pthread_t clients[CLIENTS];
    for (int i = 0; i < CLIENTS; i++) pthread_create(&clients[i], NULL, client, NULL);
    for (int i = 0; i < CLIENTS; i++) pthread_join(clients[i], NULL);
    printf("%ld\n", (long)sum);
    return 0;
}
