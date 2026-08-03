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

    private func makeSession() -> URLSession {
        stubContext.makeSession()
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
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

        let user: TestUser = try await client.request("/users/1", method: .GET)

        XCTAssertEqual(user, TestUser(id: 1, name: "Iveta"))
        XCTAssertEqual(stubContext.lastRequest?.httpMethod, "GET")
    }

    func testGETRequestThrowsStatusCodeErrorForNonSuccessResponse() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, statusCode: 404)
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    func testGETRequestThrowsStatusCodeErrorForServerErrorResponse() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, statusCode: 500)
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    func testGETRequestAcceptsBoundaryStatusCodes200And299() async throws {
        let url = URL(string: "https://api.minit.test/users/1")!
        let payload = try JSONEncoder().encode(TestUser(id: 1, name: "Iveta"))

        stubContext.stub(url: url, statusCode: 299, data: payload)
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

        let user: TestUser = try await client.request("/users/1", method: .GET)

        XCTAssertEqual(user, TestUser(id: 1, name: "Iveta"))
    }

    func testGETRequestThrowsStatusCodeErrorJustOutsideSuccessBoundary() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, statusCode: 300)
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code) {
            XCTAssertEqual(code, 300)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    func testGETRequestThrowsDecodingFailedForMalformedJSON() async {
        let url = URL(string: "https://api.minit.test/users/1")!
        stubContext.stub(url: url, statusCode: 200, data: Data("not json".utf8))
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

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
        let client = NetworkClientImpl(baseURL: "https://a b.minit.test", session: makeSession())

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
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

        let user: TestUser = try await client.request("/users", method: .POST, body: TestBody(name: "Nová"))

        XCTAssertEqual(user, TestUser(id: 2, name: "Nová"))
        XCTAssertEqual(stubContext.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(stubContext.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let sentBody = try XCTUnwrap(
            stubContext.lastRequest?.httpBodyStreamAsData() ?? stubContext.lastRequest?.httpBody
        )
        let decodedBody = try JSONDecoder().decode(TestBody.self, from: sentBody)
        XCTAssertEqual(decodedBody, TestBody(name: "Nová"))
    }

    func testPOSTRequestThrowsStatusCodeErrorForNonSuccessResponse() async {
        let url = URL(string: "https://api.minit.test/users")!
        stubContext.stub(url: url, statusCode: 422)
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

        do {
            let _: TestUser = try await client.request("/users", method: .POST, body: TestBody(name: "Nová"))
            XCTFail("Expected NetworkError.statusCode to be thrown")
        } catch let NetworkError.statusCode(code) {
            XCTAssertEqual(code, 422)
        } catch {
            XCTFail("Expected NetworkError.statusCode, got \(error)")
        }
    }

    func testPOSTRequestWithInvalidURLThrowsInvalidURLErrorWithoutEncodingBody() async {
        let client = NetworkClientImpl(baseURL: "https://a b.minit.test", session: makeSession())

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
        let client = NetworkClientImpl(baseURL: "https://api.minit.test", session: makeSession())

        do {
            let _: TestUser = try await client.request("/users/1", method: .GET)
            XCTFail("Expected the underlying URLError to propagate")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
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
