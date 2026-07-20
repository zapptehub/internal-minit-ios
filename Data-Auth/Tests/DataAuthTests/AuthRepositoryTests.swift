import XCTest
import CoreNetworking
@testable import DataAuth

final class AuthRepositoryTests: XCTestCase {
    func testLoginReturnsAuthData() async throws {
        let mockApi = MockAuthApi()
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        let result = try await repository.login(email: "test@example.com", password: "password")

        XCTAssertEqual(result.token, "test-token")
        XCTAssertTrue(mockApi.loginCalled)
    }

    func testLoginThrowsWhenApiFails() async {
        let mockApi = MockAuthApi()
        mockApi.shouldThrow = true
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        do {
            _ = try await repository.login(email: "test@example.com", password: "password")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(mockApi.loginCalled)
        }
    }

    func testRegisterReturnsAuthDataAndSavesSession() async throws {
        let mockApi = MockAuthApi()
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        let result = try await repository.register(email: "new@minit.com", password: "password", marketingOptIn: true)

        XCTAssertEqual(result.token, "test-token")
        let session = await repository.currentSession()
        XCTAssertEqual(session, result)
    }

    func testCheckEmailExistsPassesThroughApiResult() async throws {
        let mockApi = MockAuthApi()
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        let exists = try await repository.checkEmailExists(email: "iveta@minitbakery.com")

        XCTAssertTrue(exists)
    }

    func testSendVerificationCodeDoesNotThrow() async throws {
        let mockApi = MockAuthApi()
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        try await repository.sendVerificationCode(email: "iveta@minitbakery.com")
    }

    func testConfirmPasswordResetDoesNotThrow() async throws {
        let mockApi = MockAuthApi()
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        try await repository.confirmPasswordReset(email: "iveta@minitbakery.com", code: "1234")
    }
}

final class AuthApiImplTests: XCTestCase {
    func testCheckEmailExistsIsFalseOnlyForMockNewUserEmail() async throws {
        let api = AuthApiImpl(networkClient: NoopNetworkClient())

        let isNewUserEmailExisting = try await api.checkEmailExists(email: "new@minit.com")
        let isMixedCaseWithWhitespaceExisting = try await api.checkEmailExists(email: "  New@Minit.com  ")
        let isOtherEmailExisting = try await api.checkEmailExists(email: "iveta@minitbakery.com")

        XCTAssertFalse(isNewUserEmailExisting)
        XCTAssertFalse(isMixedCaseWithWhitespaceExisting)
        XCTAssertTrue(isOtherEmailExisting)
    }
}

// MARK: - Mock

private final class NoopNetworkClient: NetworkClient {
    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        throw NSError(domain: "test", code: 0)
    }

    func request<T: Decodable, B: Encodable>(_ path: String, method: HTTPMethod, body: B) async throws -> T {
        throw NSError(domain: "test", code: 0)
    }
}

// MARK: - Mock

private final class MockAuthApi: AuthApi {
    var loginCalled = false
    var shouldThrow = false

    func login(email: String, password: String) async throws -> AuthDto {
        loginCalled = true
        if shouldThrow { throw NSError(domain: "test", code: 0) }
        return AuthDto(accessToken: "test-token", userId: "test-user")
    }

    func checkEmailExists(email: String) async throws -> Bool {
        if shouldThrow { throw NSError(domain: "test", code: 0) }
        return true
    }

    func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthDto {
        if shouldThrow { throw NSError(domain: "test", code: 0) }
        return AuthDto(accessToken: "test-token", userId: "test-user")
    }

    func sendVerificationCode(email: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 0) }
    }

    func confirmPasswordReset(email: String, code: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 0) }
    }
}
