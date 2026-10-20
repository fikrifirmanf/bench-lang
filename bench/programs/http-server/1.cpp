// A minimal HTTP/1.1 server (one std::thread per connection) and a pool of keep-alive clients on POSIX sockets.
// Each client POSTs {"value": i}; the server answers with the value, and the client sums the answers.
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <strings.h>
#include <sys/socket.h>
#include <unistd.h>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <optional>
#include <random>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

constexpr int CLIENTS = 32;

class Connection {
  public:
    explicit Connection(int fd) : fd_(fd) {}
    ~Connection() { close(fd_); }
    Connection(const Connection &) = delete;

    // Reads one message (headers, then Content-Length bytes of body) and returns its body.
    std::optional<std::string> read_message() {
        size_t header_end;
        while ((header_end = buffer_.find("\r\n\r\n")) == std::string::npos)
            if (!fill()) return std::nullopt;
        size_t length = 0;
        std::string_view headers(buffer_.data(), header_end);
        for (size_t at = 0; at < headers.size();) {
            size_t eol = headers.find("\r\n", at);
            std::string_view line = headers.substr(at, eol == std::string_view::npos ? std::string_view::npos : eol - at);
            if (line.size() > 15 && strncasecmp(line.data(), "content-length:", 15) == 0)
                length = std::strtoul(std::string(line.substr(15)).c_str(), nullptr, 10);
            if (eol == std::string_view::npos) break;
            at = eol + 2;
        }
        while (buffer_.size() < header_end + 4 + length)
            if (!fill()) return std::nullopt;
        std::string body = buffer_.substr(header_end + 4, length);
        buffer_.erase(0, header_end + 4 + length);
        return body;
    }

    bool write_all(std::string_view data) {
        while (!data.empty()) {
            ssize_t sent = write(fd_, data.data(), data.size());
            if (sent <= 0) return false;
            data.remove_prefix(static_cast<size_t>(sent));
        }
        return true;
    }

  private:
    bool fill() {
        char chunk[4096];
        ssize_t got = read(fd_, chunk, sizeof chunk);
        if (got <= 0) return false;
        buffer_.append(chunk, static_cast<size_t>(got));
        return true;
    }

    int fd_;
    std::string buffer_;
};

static void serve_connection(int fd) {
    Connection connection(fd);
    while (auto body = connection.read_message()) {
        size_t field = body->find("\"value\"");
        long value = field == std::string::npos ? 0 : std::strtol(body->c_str() + body->find(':', field) + 1, nullptr, 10);
        std::string text = std::to_string(value);
        if (!connection.write_all("HTTP/1.1 200 OK\r\nContent-Length: " + std::to_string(text.size()) + "\r\n\r\n" + text))
            break;
    }
}

static int connect_server(int port) {
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_port = htons(static_cast<uint16_t>(port));
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    for (;;) {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (connect(fd, reinterpret_cast<sockaddr *>(&address), sizeof address) == 0) {
            int on = 1;
            setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &on, sizeof on);
            return fd;
        }
        close(fd);
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
}

int main(int argc, char **argv) {
    int total = argc > 1 ? std::atoi(argv[1]) : 10;
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    int on = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    std::mt19937 rng(std::random_device{}());
    int port;
    do {
        port = 20000 + static_cast<int>(rng() % 30000);
        address.sin_port = htons(static_cast<uint16_t>(port));
    } while (bind(listener, reinterpret_cast<sockaddr *>(&address), sizeof address) != 0);
    listen(listener, 512);

    std::thread([listener] {
        for (;;) {
            int fd = accept(listener, nullptr, nullptr);
            if (fd >= 0) std::thread(serve_connection, fd).detach();
        }
    }).detach();

    std::atomic<int> next_value{1};
    std::atomic<long> sum{0};
    std::vector<std::thread> clients;
    for (int c = 0; c < CLIENTS; c++) {
        clients.emplace_back([&] {
            auto connection = std::make_unique<Connection>(connect_server(port));
            for (int value; (value = next_value++) <= total;) {
                std::string payload = "{\"value\":" + std::to_string(value) + "}";
                std::string request = "POST / HTTP/1.1\r\nHost: localhost:" + std::to_string(port) +
                                      "\r\nContent-Type: application/json\r\nContent-Length: " +
                                      std::to_string(payload.size()) + "\r\n\r\n" + payload;
                std::optional<std::string> body;
                while (!connection->write_all(request) || !(body = connection->read_message()))
                    connection = std::make_unique<Connection>(connect_server(port));
                sum += std::atol(body->c_str());
            }
        });
    }
    for (auto &client : clients) client.join();
    std::printf("%ld\n", sum.load());
}
