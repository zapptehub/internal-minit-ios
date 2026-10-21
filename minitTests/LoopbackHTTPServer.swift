import Darwin
import Foundation

/// One-shot HTTP/1.1 server on 127.0.0.1. Redirect tests need a real `URLSession`
/// load: a `URLProtocol` response does not call `willPerformHTTPRedirection`.
nonisolated final class LoopbackHTTPServer: @unchecked Sendable {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "minit.loopback-http")
    private var socketFD: Int32 = -1
    private var source: DispatchSourceRead?
    private var routes: [String: Route] = [:]
    private var recorded: [RecordedRequest] = []

    struct Route {
        let status: Int
        let headers: [String: String]
        let body: Data
    }

    struct RecordedRequest {
        let path: String
        let headers: [String: String]
    }

    var requests: [RecordedRequest] {
        lock.withLock { recorded }
    }

    func respond(path: String, status: Int, headers: [String: String] = [:], body: Data = Data()) {
        lock.withLock {
            routes[path] = Route(status: status, headers: headers, body: body)
        }
    }

    func start() throws -> UInt16 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw URLError(.cannotConnectToHost) }
        socketFD = fd
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, Darwin.listen(fd, 16) == 0 else {
            Darwin.close(fd)
            throw URLError(.cannotConnectToHost)
        }
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var resolved = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &resolved) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard named == 0 else {
            Darwin.close(fd)
            throw URLError(.cannotConnectToHost)
        }
        let port = UInt16(bigEndian: resolved.sin_port)

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptPending()
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        self.source = source
        source.resume()
        return port
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }

    private func acceptPending() {
        while true {
            let client = Darwin.accept(socketFD, nil, nil)
            if client < 0 { break }
            let flags = fcntl(client, F_GETFL)
            _ = fcntl(client, F_SETFL, flags & ~O_NONBLOCK)
            handle(client)
        }
    }

    private func handle(_ client: Int32) {
        defer { Darwin.close(client) }
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while buffer.range(of: Data("\r\n\r\n".utf8)) == nil && buffer.count < 65_536 {
            let count = Darwin.read(client, &chunk, chunk.count)
            if count <= 0 { break }
            buffer.append(chunk, count: count)
        }
        let text = String(decoding: buffer, as: UTF8.self)
        let lines = text.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        let path = parts.count > 1 ? String(parts[1]) : "/"
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<separator])
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        let route = lock.withLock { () -> Route in
            recorded.append(RecordedRequest(path: path, headers: headers))
            return routes[path] ?? Route(status: 404, headers: [:], body: Data())
        }
        var raw = "HTTP/1.1 \(route.status) OK\r\nContent-Length: \(route.body.count)\r\nConnection: close\r\n"
        for (name, value) in route.headers {
            raw += "\(name): \(value)\r\n"
        }
        raw += "\r\n"
        var bytes = Data(raw.utf8)
        bytes.append(route.body)
        bytes.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var sent = 0
            while sent < bytes.count {
                let count = Darwin.write(client, base.advanced(by: sent), bytes.count - sent)
                if count <= 0 { break }
                sent += count
            }
        }
    }
}
