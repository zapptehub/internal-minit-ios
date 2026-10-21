import XCTest
import CoreNetworking
@testable import minit

final class NetworkClientImplTests: XCTestCase {
    private var stubContext: URLProtocolStub.Context!

    private struct TestUser: Codable, Equatable {
        let id: Int
        let name: String
    }

    private struct TestBody: Codable, Equatable {
        let name: String
    }

    private func makeClient(
        baseURL: String = "https://api.minit.test",
        tokenProvider: TokenProvider = StaticTokenProvider(token: nil),
        accessClientId: String = "",
        accessClientSecret: String = "",
        configuration: URLSessionConfiguration? = nil
    ) -> NetworkClientImpl {
        NetworkClientImpl(
            baseURL: baseURL,
            tokenProvider: tokenProvider,
            accessClientId: accessClientId,
            accessClientSecret: accessClientSecret,
            sessionConfiguration: configuration ?? stubContext.makeConfiguration()
        )
    }

    /// Ephemeral session with no `URLProtocol`, so redirects reach the session delegate.
    private func makeLiveClient(
        baseURL: String,
        tokenProvider: TokenProvider = StaticTokenProvider(token: "fake-token")
    ) -> NetworkClientImpl {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        return NetworkClientImpl(
            baseURL: baseURL,
            tokenProvider: tokenProvider,
            accessClientId: "fake-access-id",
            accessClientSecret: "fake-access-secret",
            sessionConfiguration: configuration
        )
    }

    private func header(_ request: LoopbackHTTPServer.RecordedRequest, _ name: String) -> String? {
        request.headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    override func setUp() {
        super.setUp()
        stubContext = URLProtocolStub.Context()
    }

    override func tearDown() {
        stubContext = nil
        super.tearDown()
    }

    // MARK: - GET

    func testGETRequestDecodesSuccessfulJSONResponse() async throws {
        let url = URL(string: "https://api.minit.test/users/1")!
        let payload = try JSONEncoder().encode(TestUser(id: 1, name: "Iveta"))
        stubContext.stub(url: url, statusCode: 200, data: payload)
        let client = makeClient()

        let user: TestUser = try await client.request("/users/1", method: .GET)

        XCTAssertEqual(user, TestUser(id: 1, name: "Iveta"))
        XCTAssertEqual(stubContext.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(stubContext.lastRequest?.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testGETRequestThrowsStatusCodeErrorForNonSuccessResponse() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, statusCode: 404)
        let client = makeClient()

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code, _) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    func testGETRequestThrowsStatusCodeErrorForServerErrorResponse() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, statusCode: 500)
        let client = makeClient()

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code, _) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    func testGETRequestAcceptsBoundaryStatusCodes200And299() async throws {
        let url = URL(string: "https://api.minit.test/users/1")!
        let payload = try JSONEncoder().encode(TestUser(id: 1, name: "Iveta"))

        stubContext.stub(url: url, statusCode: 299, data: payload)
        let client = makeClient()

        let user: TestUser = try await client.request("/users/1", method: .GET)

        XCTAssertEqual(user, TestUser(id: 1, name: "Iveta"))
    }

    func testGETRequestThrowsStatusCodeErrorJustOutsideSuccessBoundary() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, statusCode: 300)
        let client = makeClient()

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code, _) {
            XCTAssertEqual(code, 300)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    func testGETRequestThrowsDecodingFailedForMalformedJSON() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, statusCode: 200, data: Data("not json".utf8))
        let client = makeClient()

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected NetworkError.decodingFailed to be thrown")
        } catch NetworkError.decodingFailed {
            // expected
        } catch {
            XCTFail("Expected NetworkError.decodingFailed, got \(error)")
        }
    }

    func testInvalidURLThrowsInvalidURLError() async {
        // A space in the host is one of the few inputs `URL(string:)` still reliably rejects.
        let client = makeClient(baseURL: "https://a b.minit.test")

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected NetworkError.invalidURL to be thrown")
        } catch NetworkError.invalidURL {
            // expected
        } catch {
            XCTFail("Expected NetworkError.invalidURL, got \(error)")
        }
    }

    // MARK: - POST with body

    func testPOSTRequestSendsJSONEncodedBodyAndDecodesResponse() async throws {
        let url = URL(string: "https://api.minit.test/users")!
        let payload = try JSONEncoder().encode(TestUser(id: 2, name: "Nová"))
        stubContext.stub(url: url, statusCode: 201, data: payload)
        let client = makeClient()

        let user: TestUser = try await client.request("/users", method: .POST, body: TestBody(name: "Nová"))

        XCTAssertEqual(user, TestUser(id: 2, name: "Nová"))
        XCTAssertEqual(stubContext.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(stubContext.lastRequest?.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(stubContext.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let sentBody = try XCTUnwrap(
            stubContext.lastRequest?.httpBodyStreamAsData() ?? stubContext.lastRequest?.httpBody
        )
        let decodedBody = try JSONDecoder().decode(TestBody.self, from: sentBody)
        XCTAssertEqual(decodedBody, TestBody(name: "Nová"))
    }

    func testPOSTRequestThrowsStatusCodeErrorForNonSuccessResponse() async {
        let url = URL(string: "https://api.minit.test/users")!
        let body = Data(#"{"error":"invalid"}"#.utf8)
        stubContext.stub(url: url, statusCode: 422, data: body)
        let client = makeClient()

        do {
            let _: TestUser = try await client.request("/users", method: .POST, body: TestBody(name: "Nová"))
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code, responseBody) {
            XCTAssertEqual(code, 422)
            XCTAssertEqual(responseBody, body)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    func testPOSTRequestWithInvalidURLThrowsInvalidURLErrorWithoutEncodingBody() async {
        let client = makeClient(baseURL: "https://a b.minit.test")

        do {
            let _: TestUser = try await client.request("/users", method: .POST, body: TestBody(name: "Nová"))
            XCTFail("Expected NetworkError.invalidURL to be thrown")
        } catch NetworkError.invalidURL {
            // expected
        } catch {
            XCTFail("Expected NetworkError.invalidURL, got \(error)")
        }
    }

    // MARK: - Underlying transport errors

    func testRequestPropagatesUnderlyingTransportError() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, error: URLError(.notConnectedToInternet))
        let client = makeClient()

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected the underlying URLError to propagate")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    // MARK: - Host-scoped credentials

    func testBearerAndAccessAreAttachedOnlyOnTheAPIOrigin() async throws {
        let api = URL(string: "https://api.minit.test/mock/min/v1/me")!
        let explicitPort = URL(string: "https://api.minit.test:443/v1/healthz")!
        let otherPort = URL(string: "https://api.minit.test:8443/v1/me")!
        let otherScheme = URL(string: "http://api.minit.test/v1/me")!
        let foreign = URL(string: "https://cdn.example/avatar.webp")!
        let bytes = Data("ok".utf8)
        for url in [api, explicitPort, otherPort, otherScheme, foreign] {
            stubContext.stub(url: url, statusCode: 200, data: bytes)
        }

        let tokens = RecordingTokenProvider(initial: "fake-token")
        let client = makeClient(
            baseURL: "https://api.minit.test/mock/min",
            tokenProvider: tokens,
            accessClientId: "fake-access-id",
            accessClientSecret: "fake-access-secret"
        )

        let apiBytes = try await client.data(api)
        XCTAssertEqual(apiBytes, bytes)
        assertCredentials(stubContext.requests[0], bearer: "Bearer fake-token", accessAttached: true)

        let portBytes = try await client.data(explicitPort)
        XCTAssertEqual(portBytes, bytes)
        assertCredentials(stubContext.requests[1], bearer: "Bearer fake-token", accessAttached: true)

        for (offset, url) in [otherPort, otherScheme, foreign].enumerated() {
            let loaded = try await client.data(url)
            XCTAssertEqual(loaded, bytes)
            assertCredentials(stubContext.requests[offset + 2], bearer: nil, accessAttached: false)
        }
        XCTAssertEqual(tokens.refreshes, [false, false])
    }

    func testEmptyAccessHeadersAreOmitted() async throws {
        let url = URL(string: "https://api.minit.test/v1/me")!
        stubContext.stub(url: url, statusCode: 200, data: Data("{}".utf8))
        let cases = [
            ("", ""),
            ("fake-access-id", ""),
            ("", "fake-access-secret"),
            ("  ", "fake-access-secret"),
            ("$(CF_ACCESS_CLIENT_ID)", "$(CF_ACCESS_CLIENT_SECRET)"),
        ]

        for (clientId, clientSecret) in cases {
            let client = makeClient(
                tokenProvider: StaticTokenProvider(token: "fake-token"),
                accessClientId: clientId,
                accessClientSecret: clientSecret
            )
            let _: Data = try await client.data(url)
            let request = try XCTUnwrap(stubContext.requests.last)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fake-token")
            XCTAssertNil(request.value(forHTTPHeaderField: "CF-Access-Client-Id"))
            XCTAssertNil(request.value(forHTTPHeaderField: "CF-Access-Client-Secret"))
        }
    }

    func testForeignHostStripsPresetCredentialHeaders() async throws {
        let foreign = URL(string: "https://cdn.example/avatar.webp")!
        var request = URLRequest(url: foreign)
        request.setValue("Bearer leaked", forHTTPHeaderField: "Authorization")
        request.setValue("fake-access-id", forHTTPHeaderField: "CF-Access-Client-Id")
        request.setValue("fake-access-secret", forHTTPHeaderField: "CF-Access-Client-Secret")
        request.setValue("jwt", forHTTPHeaderField: "CF-Access-Jwt-Assertion")
        request.setValue("image/webp", forHTTPHeaderField: "Accept")

        let tokens = RecordingTokenProvider(initial: "fake-token")
        let client = makeClient(
            tokenProvider: tokens,
            accessClientId: "fake-access-id",
            accessClientSecret: "fake-access-secret"
        )
        let prepared = await client.preparedRequest(request)
        XCTAssertNil(prepared.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(prepared.value(forHTTPHeaderField: "CF-Access-Client-Id"))
        XCTAssertNil(prepared.value(forHTTPHeaderField: "CF-Access-Client-Secret"))
        XCTAssertNil(prepared.value(forHTTPHeaderField: "CF-Access-Jwt-Assertion"))
        XCTAssertEqual(prepared.value(forHTTPHeaderField: "Accept"), "image/webp")
        XCTAssertEqual(tokens.refreshes, [])

        stubContext.stub(url: foreign, statusCode: 200, data: Data("img".utf8))
        let configuration = stubContext.makeConfiguration(extraHeaders: [
            "Authorization": "Bearer leaked",
            "CF-Access-Client-Id": "fake-access-id",
            "CF-Access-Client-Secret": "fake-access-secret",
        ])
        let wired = makeClient(
            tokenProvider: tokens,
            accessClientId: "fake-access-id",
            accessClientSecret: "fake-access-secret",
            configuration: configuration
        )
        let bytes = try await wired.data(foreign)
        XCTAssertEqual(bytes, Data("img".utf8))
        assertCredentials(stubContext.requests.last, bearer: nil, accessAttached: false)
    }

    func testRedirectOffOriginIsNotFollowed() async throws {
        let api = LoopbackHTTPServer()
        let foreign = LoopbackHTTPServer()
        let apiPort = try api.start()
        let foreignPort = try foreign.start()
        defer {
            api.stop()
            foreign.stop()
        }
        let foreignURL = "http://127.0.0.1:\(foreignPort)/steal"
        api.respond(
            path: "/v1/me",
            status: 302,
            headers: ["Location": foreignURL],
            body: Data("go-away".utf8)
        )
        foreign.respond(path: "/steal", status: 200, body: Data("stolen".utf8))
        let client = makeLiveClient(baseURL: "http://127.0.0.1:\(apiPort)")

        do {
            let _: Data = try await client.data(URL(string: "http://127.0.0.1:\(apiPort)/v1/me")!)
            XCTFail("Expected the off-origin redirect to come back as a status code")
        } catch let NetworkError.statusCode(code, body) {
            XCTAssertEqual(code, 302)
            XCTAssertEqual(body, Data("go-away".utf8))
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }

        let seen = api.requests
        XCTAssertEqual(seen.map(\.path), ["/v1/me"])
        XCTAssertEqual(header(seen[0], "Authorization"), "Bearer fake-token")
        XCTAssertEqual(header(seen[0], "CF-Access-Client-Secret"), "fake-access-secret")
        XCTAssertEqual(foreign.requests.map(\.path), [])
    }

    func testSameOriginRedirectIsFollowedWithCredentials() async throws {
        let api = LoopbackHTTPServer()
        let port = try api.start()
        defer { api.stop() }
        let next = "http://127.0.0.1:\(port)/v1/me/final"
        api.respond(path: "/v1/me", status: 302, headers: ["Location": next], body: Data("hop".utf8))
        api.respond(path: "/v1/me/final", status: 200, body: Data("final".utf8))
        let tokens = RecordingTokenProvider(initial: "fake-token")
        let client = makeLiveClient(baseURL: "http://127.0.0.1:\(port)", tokenProvider: tokens)

        let bytes = try await client.data(URL(string: "http://127.0.0.1:\(port)/v1/me")!)
        XCTAssertEqual(bytes, Data("final".utf8))
        let seen = api.requests
        XCTAssertEqual(seen.map(\.path), ["/v1/me", "/v1/me/final"])
        for request in seen {
            XCTAssertEqual(header(request, "Authorization"), "Bearer fake-token")
            XCTAssertEqual(header(request, "CF-Access-Client-Id"), "fake-access-id")
            XCTAssertEqual(header(request, "CF-Access-Client-Secret"), "fake-access-secret")
        }
        XCTAssertEqual(tokens.refreshes, [false, false])
    }

    func testSameHostDifferentPortRedirectIsNotFollowed() async throws {
        let api = LoopbackHTTPServer()
        let otherPort = LoopbackHTTPServer()
        let apiPort = try api.start()
        let other = try otherPort.start()
        defer {
            api.stop()
            otherPort.stop()
        }
        let redirected = "http://127.0.0.1:\(other)/v1/me"
        api.respond(
            path: "/v1/me",
            status: 302,
            headers: ["Location": redirected],
            body: Data("stay".utf8)
        )
        otherPort.respond(path: "/v1/me", status: 200, body: Data("other-port".utf8))
        let client = makeLiveClient(baseURL: "http://127.0.0.1:\(apiPort)")

        do {
            let _: Data = try await client.data(URL(string: "http://127.0.0.1:\(apiPort)/v1/me")!)
            XCTFail("Expected the different-port redirect to come back as a status code")
        } catch let NetworkError.statusCode(code, body) {
            XCTAssertEqual(code, 302)
            XCTAssertEqual(body, Data("stay".utf8))
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }

        XCTAssertEqual(api.requests.map(\.path), ["/v1/me"])
        XCTAssertEqual(header(api.requests[0], "Authorization"), "Bearer fake-token")
        XCTAssertEqual(otherPort.requests.map(\.path), [])
    }

    func testDelegateRefusesSameHostHTTPSDowngrade() async {
        let delegate = HostScopedSessionDelegate(
            baseURL: "https://api.minit.test",
            tokenProvider: StaticTokenProvider(token: "fake-token"),
            accessClientId: "fake-access-id",
            accessClientSecret: "fake-access-secret"
        )
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let original = URL(string: "https://api.minit.test/v1/me")!
        let destination = URL(string: "http://api.minit.test/v1/me")!
        let task = session.dataTask(with: original)
        let response = HTTPURLResponse(
            url: original,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": destination.absoluteString]
        )!
        let followed: URLRequest? = await withCheckedContinuation { continuation in
            delegate.urlSession(
                session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: URLRequest(url: destination)
            ) { request in
                continuation.resume(returning: request)
            }
        }
        XCTAssertNil(followed)
    }

    func testUnauthorizedIsRetriedOnceWithRefreshedBearer() async throws {
        let url = URL(string: "https://api.minit.test/v1/me")!
        let payload = try JSONEncoder().encode(TestUser(id: 1, name: "Iveta"))
        stubContext.enqueue(url: url, statusCode: 401, data: Data("first".utf8))
        stubContext.enqueue(url: url, statusCode: 200, data: payload)
        let refreshed = RecordingTokenProvider(initial: "fake-token", refreshed: "fake-token-refreshed")
        let client = makeClient(tokenProvider: refreshed)

        let user: TestUser = try await client.request("/v1/me", method: .GET)
        XCTAssertEqual(user, TestUser(id: 1, name: "Iveta"))
        XCTAssertEqual(refreshed.refreshes, [false, true])
        XCTAssertEqual(stubContext.requests.count, 2)
        XCTAssertEqual(stubContext.requests.map { $0.value(forHTTPHeaderField: "Authorization") }, [
            "Bearer fake-token",
            "Bearer fake-token-refreshed",
        ])
    }

    func testSecondUnauthorizedIsReturnedWithoutAnotherRetry() async throws {
        let url = URL(string: "https://api.minit.test/v1/me")!
        let stopped = RecordingTokenProvider(initial: "fake-token", refreshed: "fake-token-refreshed")
        let client = makeClient(tokenProvider: stopped)
        stubContext.enqueue(url: url, statusCode: 401, data: Data("a".utf8))
        stubContext.enqueue(url: url, statusCode: 401, data: Data("b".utf8))

        do {
            let _: TestUser = try await client.request("/v1/me", method: .GET)
            XCTFail("Expected the second 401 to be returned")
        } catch let NetworkError.statusCode(code, body) {
            XCTAssertEqual(code, 401)
            XCTAssertEqual(body, Data("b".utf8))
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
        XCTAssertEqual(stopped.refreshes, [false, true])
        XCTAssertEqual(stubContext.requests.count, 2)
    }

    func testUnauthorizedWithoutBearerIsNotRetried() async {
        let url = URL(string: "https://api.minit.test/v1/me")!
        let anonymous = RecordingTokenProvider(initial: nil)
        let client = makeClient(tokenProvider: anonymous)
        stubContext.enqueue(url: url, statusCode: 401, data: Data("no-session".utf8))

        do {
            let _: TestUser = try await client.request("/v1/me", method: .GET)
            XCTFail("Expected a 401 without a bearer token")
        } catch let NetworkError.statusCode(code, body) {
            XCTAssertEqual(code, 401)
            XCTAssertEqual(body, Data("no-session".utf8))
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
        XCTAssertEqual(anonymous.refreshes, [false])
        XCTAssertEqual(stubContext.requests.count, 1)
        XCTAssertNil(stubContext.requests.last?.value(forHTTPHeaderField: "Authorization"))
    }

    func testUnauthorizedSkipsRetryWhenRefreshReturnsNil() async {
        let url = URL(string: "https://api.minit.test/v1/me")!
        stubContext.enqueue(url: url, statusCode: 401, data: Data("first".utf8))
        stubContext.enqueue(url: url, statusCode: 200, data: Data(#"{"id":1,"name":"Iveta"}"#.utf8))
        let tokens = RecordingTokenProvider(initial: "fake-token", refreshReturnsNil: true)
        let client = makeClient(tokenProvider: tokens)

        do {
            let _: TestUser = try await client.request("/v1/me", method: .GET)
            XCTFail("Expected the first 401 when refresh returns nil")
        } catch let NetworkError.statusCode(code, body) {
            XCTAssertEqual(code, 401)
            XCTAssertEqual(body, Data("first".utf8))
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
        XCTAssertEqual(tokens.refreshes, [false, true])
        XCTAssertEqual(stubContext.requests.count, 1)
        XCTAssertEqual(stubContext.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer fake-token")
    }

    func testUnauthorizedSkipsRetryWhenRefreshReturnsEmpty() async {
        let url = URL(string: "https://api.minit.test/v1/me")!
        stubContext.enqueue(url: url, statusCode: 401, data: Data("first".utf8))
        stubContext.enqueue(url: url, statusCode: 200, data: Data(#"{"id":1,"name":"Iveta"}"#.utf8))
        let tokens = RecordingTokenProvider(initial: "fake-token", refreshed: "")
        let client = makeClient(tokenProvider: tokens)

        do {
            let _: TestUser = try await client.request("/v1/me", method: .GET)
            XCTFail("Expected the first 401 when refresh returns an empty token")
        } catch let NetworkError.statusCode(code, body) {
            XCTAssertEqual(code, 401)
            XCTAssertEqual(body, Data("first".utf8))
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
        XCTAssertEqual(tokens.refreshes, [false, true])
        XCTAssertEqual(stubContext.requests.count, 1)
        XCTAssertEqual(stubContext.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer fake-token")
    }

    func testDataReturnsBytes() async throws {
        let url = URL(string: "https://api.minit.test/v1/media/avatars/default.webp")!
        let bytes = Data([0x00, 0x01, 0x02, 0xFF])
        stubContext.stub(url: url, statusCode: 200, data: bytes)
        let client = makeClient(
            tokenProvider: StaticTokenProvider(token: "fake-token"),
            accessClientId: "fake-access-id",
            accessClientSecret: "fake-access-secret"
        )

        let loaded = try await client.data(url)
        XCTAssertEqual(loaded, bytes)
        XCTAssertEqual(stubContext.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(stubContext.lastRequest?.cachePolicy, .useProtocolCachePolicy)
        assertCredentials(stubContext.lastRequest, bearer: "Bearer fake-token", accessAttached: true)
    }

    func testDataThrowsStatusCodeWithBody() async {
        let url = URL(string: "https://api.minit.test/v1/media/avatars/default.webp")!
        let body = Data(#"{"error":"invalid"}"#.utf8)
        stubContext.stub(url: url, statusCode: 422, data: body)
        let client = makeClient()

        do {
            _ = try await client.data(url)
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code, responseBody) {
            XCTAssertEqual(code, 422)
            XCTAssertEqual(responseBody, body)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    private func assertCredentials(
        _ request: URLRequest?,
        bearer: String?,
        accessAttached: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), bearer, file: file, line: line)
        if accessAttached {
            XCTAssertEqual(request?.value(forHTTPHeaderField: "CF-Access-Client-Id"), "fake-access-id", file: file, line: line)
            XCTAssertEqual(request?.value(forHTTPHeaderField: "CF-Access-Client-Secret"), "fake-access-secret", file: file, line: line)
        } else {
            let names = request?.allHTTPHeaderFields?.keys.map { $0.lowercased() } ?? []
            XCTAssertFalse(names.contains { $0.hasPrefix("cf-access-") }, file: file, line: line)
        }
    }
}

nonisolated struct StaticTokenProvider: TokenProvider, Sendable {
    let token: String?

    func currentToken(forceRefresh: Bool) async -> String? {
        token
    }
}

nonisolated final class RecordingTokenProvider: TokenProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let initial: String?
    private let refreshed: String?
    private let refreshReturnsNil: Bool
    private var recorded: [Bool] = []

    init(initial: String?, refreshed: String? = nil, refreshReturnsNil: Bool = false) {
        self.initial = initial
        self.refreshed = refreshed
        self.refreshReturnsNil = refreshReturnsNil
    }

    var refreshes: [Bool] {
        lock.withLock { recorded }
    }

    func currentToken(forceRefresh: Bool) async -> String? {
        lock.withLock {
            recorded.append(forceRefresh)
            if forceRefresh && refreshReturnsNil {
                return nil
            }
            return forceRefresh ? (refreshed ?? initial) : initial
        }
    }
}

private extension URLRequest {
    /// `httpBody` is nil for requests executed through `URLSession` (the body is exposed as a
    /// stream instead); this reads that stream back into `Data` so tests can assert on it.
    func httpBodyStreamAsData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read < 0 { break }
            if read == 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
