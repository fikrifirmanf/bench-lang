// A minimal HTTP/1.1 server (one thread per connection) and a pool of keep-alive client threads, on std.net.
// Each client POSTs {"value": i}; the server answers with the value, and the client sums the answers.
const std = @import("std");

const CLIENTS = 32;

var total: u32 = 0;
var next_value = std.atomic.Value(u32).init(1);
var sum = std.atomic.Value(u64).init(0);

const Connection = struct {
    stream: std.net.Stream,
    buffer: [8192]u8 = undefined,
    used: usize = 0,

    // Reads one message (headers, then Content-Length bytes of body) and returns its body, or null at EOF.
    fn readMessage(self: *Connection) !?[]const u8 {
        while (true) {
            if (std.mem.indexOf(u8, self.buffer[0..self.used], "\r\n\r\n")) |header_end| {
                var length: usize = 0;
                var lines = std.mem.splitSequence(u8, self.buffer[0..header_end], "\r\n");
                while (lines.next()) |line| {
                    if (line.len > 15 and std.ascii.eqlIgnoreCase(line[0..15], "content-length:")) {
                        length = try std.fmt.parseInt(usize, std.mem.trim(u8, line[15..], " "), 10);
                    }
                }
                const end = header_end + 4 + length;
                while (self.used < end) {
                    if (!try self.fill()) return null;
                }
                // Copy the body to the front so the buffer can be reused for the next message.
                const body_len = length;
                std.mem.copyForwards(u8, self.buffer[0..body_len], self.buffer[header_end + 4 .. end]);
                std.mem.copyForwards(u8, self.buffer[body_len .. body_len + self.used - end], self.buffer[end..self.used]);
                self.used = body_len + self.used - end;
                const body = self.buffer[0..body_len];
                return body;
            }
            if (!try self.fill()) return null;
        }
    }

    fn consume(self: *Connection, body_len: usize) void {
        std.mem.copyForwards(u8, self.buffer[0 .. self.used - body_len], self.buffer[body_len..self.used]);
        self.used -= body_len;
    }

    fn fill(self: *Connection) !bool {
        const got = try self.stream.read(self.buffer[self.used..]);
        if (got == 0) return false;
        self.used += got;
        return true;
    }
};

fn parseValue(body: []const u8) !i64 {
    const field = std.mem.indexOf(u8, body, "\"value\"") orelse return 0;
    const colon = std.mem.indexOfScalarPos(u8, body, field, ':') orelse return 0;
    var end = colon + 1;
    while (end < body.len and (body[end] == ' ' or body[end] == '-' or std.ascii.isDigit(body[end]))) end += 1;
    return std.fmt.parseInt(i64, std.mem.trim(u8, body[colon + 1 .. end], " "), 10);
}

fn serveConnection(stream: std.net.Stream) void {
    defer stream.close();
    var connection = Connection{ .stream = stream };
    while (true) {
        const body = (connection.readMessage() catch return) orelse return;
        const value = parseValue(body) catch 0;
        connection.consume(body.len);
        var text: [32]u8 = undefined;
        const value_text = std.fmt.bufPrint(&text, "{d}", .{value}) catch return;
        var response: [128]u8 = undefined;
        const message = std.fmt.bufPrint(&response, "HTTP/1.1 200 OK\r\nContent-Length: {d}\r\n\r\n{s}", .{ value_text.len, value_text }) catch return;
        stream.writeAll(message) catch return;
    }
}

fn serve(server: *std.net.Server) void {
    while (true) {
        const connection = server.accept() catch continue;
        const thread = std.Thread.spawn(.{}, serveConnection, .{connection.stream}) catch {
            connection.stream.close();
            continue;
        };
        thread.detach();
    }
}

fn connect(address: std.net.Address) std.net.Stream {
    while (true) {
        return std.net.tcpConnectToAddress(address) catch {
            std.time.sleep(std.time.ns_per_ms);
            continue;
        };
    }
}

fn client(address: std.net.Address) void {
    var connection = Connection{ .stream = connect(address) };
    defer connection.stream.close();
    while (true) {
        const value = next_value.fetchAdd(1, .monotonic);
        if (value > total) return;
        var payload_buffer: [64]u8 = undefined;
        const payload = std.fmt.bufPrint(&payload_buffer, "{{\"value\":{d}}}", .{value}) catch return;
        var request_buffer: [256]u8 = undefined;
        const request = std.fmt.bufPrint(&request_buffer, "POST / HTTP/1.1\r\nHost: localhost:{d}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n{s}", .{ address.getPort(), payload.len, payload }) catch return;
        while (true) {
            if (connection.stream.writeAll(request)) {
                if (connection.readMessage() catch null) |body| {
                    const answer = std.fmt.parseInt(u64, body, 10) catch 0;
                    connection.consume(body.len);
                    _ = sum.fetchAdd(answer, .monotonic);
                    break;
                }
            } else |_| {}
            connection.stream.close();
            connection = Connection{ .stream = connect(address) };
        }
    }
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    total = if (args.next()) |arg| try std.fmt.parseInt(u32, arg, 10) else 10;

    var server: std.net.Server = undefined;
    var address: std.net.Address = undefined;
    while (true) {
        const port = std.crypto.random.intRangeAtMost(u16, 20000, 49999);
        address = try std.net.Address.parseIp4("127.0.0.1", port);
        server = address.listen(.{ .reuse_address = true, .kernel_backlog = 512 }) catch continue;
        break;
    }
    const server_thread = try std.Thread.spawn(.{}, serve, .{&server});
    server_thread.detach();

    var clients: [CLIENTS]std.Thread = undefined;
    for (&clients) |*thread| thread.* = try std.Thread.spawn(.{}, client, .{address});
    for (clients) |thread| thread.join();
    try std.io.getStdOut().writer().print("{d}\n", .{sum.load(.monotonic)});
}
