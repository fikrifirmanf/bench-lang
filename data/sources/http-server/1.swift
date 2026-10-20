// A minimal HTTP/1.1 server (one thread per connection) and a pool of keep-alive client threads, on Glibc
// sockets. Each client POSTs {"value": i}; the server answers with the value, and the client sums the answers.
import Foundation
#if canImport(Glibc)
import Glibc
#endif

let clientCount = 32

final class Connection {
    let fd: Int32
    private var buffer = [UInt8]()

    init(fd: Int32) { self.fd = fd }
    deinit { close(fd) }

    private func fill() -> Bool {
        var chunk = [UInt8](repeating: 0, count: 4096)
        let got = chunk.withUnsafeMutableBytes { read(fd, $0.baseAddress, 4096) }
        if got <= 0 { return false }
        buffer += chunk[0..<got]
        return true
    }

    // Reads one message (headers, then Content-Length bytes of body) and returns its body.
    func readMessage() -> [UInt8]? {
        let separator: [UInt8] = [13, 10, 13, 10]
        var headerEnd = -1
        while headerEnd < 0 {
            if buffer.count >= 4 {
                for i in 0...(buffer.count - 4) where buffer[i..<(i + 4)].elementsEqual(separator) {
                    headerEnd = i
                    break
                }
            }
            if headerEnd < 0 && !fill() { return nil }
        }
        var length = 0
        let headers = String(decoding: buffer[0..<headerEnd], as: UTF8.self)
        for line in headers.split(separator: "\r\n") where line.lowercased().hasPrefix("content-length:") {
            length = Int(line.dropFirst(15).trimmingCharacters(in: .whitespaces)) ?? 0
        }
        let end = headerEnd + 4 + length
        while buffer.count < end {
            if !fill() { return nil }
        }
        let body = Array(buffer[(headerEnd + 4)..<end])
        buffer.removeFirst(end)
        return body
    }

    func writeAll(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        var offset = 0
        while offset < bytes.count {
            let sent = bytes.withUnsafeBytes { write(fd, $0.baseAddress! + offset, $0.count - offset) }
            if sent <= 0 { return false }
            offset += sent
        }
        return true
    }
}

func serveConnection(_ fd: Int32) {
    let connection = Connection(fd: fd)
    while let body = connection.readMessage() {
        let text = String(decoding: body, as: UTF8.self)
        var value = 0
        if let field = text.range(of: "\"value\""), let colon = text[field.upperBound...].firstIndex(of: ":") {
            value = Int(text[text.index(after: colon)...].prefix { $0 == "-" || $0.isNumber || $0 == " " }
                .trimmingCharacters(in: .whitespaces)) ?? 0
        }
        let answer = String(value)
        if !connection.writeAll("HTTP/1.1 200 OK\r\nContent-Length: \(answer.utf8.count)\r\n\r\n\(answer)") { break }
    }
}

func loopbackAddress(_ port: UInt16) -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr.s_addr = UInt32(0x7f00_0001).bigEndian
    return address
}

func connectServer(_ port: UInt16) -> Int32 {
    while true {
        let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        var address = loopbackAddress(port)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        if result == 0 {
            var on: Int32 = 1
            setsockopt(fd, Int32(IPPROTO_TCP), TCP_NODELAY, &on, socklen_t(MemoryLayout<Int32>.size))
            return fd
        }
        close(fd)
        usleep(1000)
    }
}

let total = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 10
let listener = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
var on: Int32 = 1
setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))
var port: UInt16 = 0
while true {
    port = UInt16.random(in: 20000..<50000)
    var address = loopbackAddress(port)
    let bound = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
    }
    if bound == 0 { break }
}
listen(listener, 512)
Thread.detachNewThread {
    while true {
        let fd = accept(listener, nil, nil)
        if fd >= 0 { Thread.detachNewThread { serveConnection(fd) } }
    }
}

let lock = NSLock()
var nextValue = 1
var sum = 0
let group = DispatchGroup()
for _ in 0..<clientCount {
    group.enter()
    Thread.detachNewThread {
        var connection = Connection(fd: connectServer(port))
        var mine = 0
        while true {
            lock.lock()
            let value = nextValue
            nextValue += 1
            lock.unlock()
            if value > total { break }
            let payload = "{\"value\":\(value)}"
            let request = "POST / HTTP/1.1\r\nHost: localhost:\(port)\r\nContent-Type: application/json\r\nContent-Length: \(payload.utf8.count)\r\n\r\n\(payload)"
            while true {
                if connection.writeAll(request), let body = connection.readMessage() {
                    mine += Int(String(decoding: body, as: UTF8.self)) ?? 0
                    break
                }
                connection = Connection(fd: connectServer(port))
            }
        }
        lock.lock()
        sum += mine
        lock.unlock()
        group.leave()
    }
}
group.wait()
print(sum)
