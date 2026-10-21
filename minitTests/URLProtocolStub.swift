import Foundation

/// Intercepts every request made through a `URLSession` configured with this protocol class,
/// so `NetworkClientImpl` can be exercised against canned responses without touching the
/// network. Each test owns a `Context`, so parallel tests never share stubs or captured
/// requests even though `URLProtocol` itself must be registered by class.
final class URLProtocolStub: URLProtocol {
    struct Stub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    final class Context: @unchecked Sendable {
        private let identifier = UUID().uuidString
        private let lock = NSLock()
        private var repeatingStubs: [String: Stub] = [:]
        private var queuedStubs: [String: [Stub]] = [:]
        private var capturedRequests: [URLRequest] = []

        var lastRequest: URLRequest? {
            lock.withLock { capturedRequests.last }
        }

        var requests: [URLRequest] {
            lock.withLock { capturedRequests }
        }

        func makeConfiguration(extraHeaders: [String: String] = [:]) -> URLSessionConfiguration {
            URLProtocolStub.register(self, identifier: identifier)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [URLProtocolStub.self]
            var headers = [URLProtocolStub.contextHeader: identifier]
            for (key, value) in extraHeaders {
                headers[key] = value
            }
            configuration.httpAdditionalHeaders = headers
            return configuration
        }

        func makeSession() -> URLSession {
            URLSession(configuration: makeConfiguration())
        }

        func stub(
            url: URL,
            statusCode: Int,
            data: Data? = nil,
            headers: [String: String] = [:]
        ) {
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )
            lock.withLock {
                repeatingStubs[url.absoluteString] = Stub(data: data, response: response, error: nil)
            }
        }

        /// Responses are consumed in order. A repeating `stub` is used once the queue is empty.
        func enqueue(
            url: URL,
            statusCode: Int,
            data: Data? = nil,
            headers: [String: String] = [:]
        ) {
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )
            lock.withLock {
                queuedStubs[url.absoluteString, default: []].append(
                    Stub(data: data, response: response, error: nil)
                )
            }
        }

        func stub(url: URL, error: Error) {
            lock.withLock {
                repeatingStubs[url.absoluteString] = Stub(data: nil, response: nil, error: error)
            }
        }

        fileprivate func stub(for url: URL) -> Stub? {
            lock.withLock {
                let key = url.absoluteString
                if var queue = queuedStubs[key], !queue.isEmpty {
                    let next = queue.removeFirst()
                    queuedStubs[key] = queue
                    return next
                }
                return repeatingStubs[key]
            }
        }

        fileprivate func capture(_ request: URLRequest) {
            lock.withLock {
                capturedRequests.append(request)
            }
        }
    }

    private final class WeakContext {
        weak var value: Context?

        init(_ value: Context) {
            self.value = value
        }
    }

    private static let contextHeader = "X-Minit-URLProtocolStub-Context"
    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var contexts: [String: WeakContext] = [:]

    private static func register(_ context: Context, identifier: String) {
        registryLock.withLock {
            contexts = contexts.filter { $0.value.value != nil }
            contexts[identifier] = WeakContext(context)
        }
    }

    private static func context(for identifier: String) -> Context? {
        registryLock.withLock { contexts[identifier]?.value }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard
            let identifier = request.value(forHTTPHeaderField: Self.contextHeader),
            let context = Self.context(for: identifier),
            let url = request.url
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        context.capture(request)

        guard let stub = context.stub(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if let response = stub.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = stub.data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
