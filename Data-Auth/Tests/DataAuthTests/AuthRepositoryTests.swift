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
        let session = try await repository.currentSession()
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

    func testCurrentSession_returnsCachedSessionWithoutRestoring() async throws {
        let mockApi = MockAuthApi()
        let dataSource = InMemoryAuthDataSource()
        await dataSource.save(AuthData(token: "cached-token", userId: "cached-user"))
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        let session = try await repository.currentSession()

        XCTAssertEqual(session, AuthData(token: "cached-token", userId: "cached-user"))
        XCTAssertFalse(mockApi.restoreSessionCalled)
    }

    func testCurrentSession_restoresFromBackendWhenCacheIsEmptyAndCachesResult() async throws {
        let mockApi = MockAuthApi()
        mockApi.restoreSessionResult = .success(AuthDto(accessToken: "restored-token", userId: "restored-user"))
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        let session = try await repository.currentSession()

        XCTAssertEqual(session, AuthData(token: "restored-token", userId: "restored-user"))
        XCTAssertTrue(mockApi.restoreSessionCalled)
        let cached = await dataSource.load()
        XCTAssertEqual(cached, session)
    }

    func testCurrentSession_returnsNilWhenNothingToRestore() async throws {
        let mockApi = MockAuthApi()
        mockApi.restoreSessionResult = .success(nil)
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        let session = try await repository.currentSession()

        XCTAssertNil(session)
        let cached = await dataSource.load()
        XCTAssertNil(cached)
    }

    func testCurrentSession_propagatesRestorationErrorInsteadOfTreatingItAsSignedOut() async {
        let mockApi = MockAuthApi()
        mockApi.restoreSessionResult = .failure(NSError(domain: "test", code: 1))
        let dataSource = InMemoryAuthDataSource()
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        do {
            _ = try await repository.currentSession()
            XCTFail("Expected the restoration error to propagate")
        } catch {
            // Expected — an indeterminate restoration failure is not the same as being
            // signed out, so the caller must see it rather than silently getting nil.
        }
        let cached = await dataSource.load()
        XCTAssertNil(cached)
    }

    func testLogout_clearsLocalCacheAndSignsOutOfBackend() async {
        let mockApi = MockAuthApi()
        let dataSource = InMemoryAuthDataSource()
        await dataSource.save(AuthData(token: "token", userId: "user"))
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        await repository.logout()

        let cached = await dataSource.load()
        XCTAssertNil(cached)
        XCTAssertTrue(mockApi.signOutCalled)
    }

    func testLogout_stillClearsLocalCacheWhenBackendSignOutFails() async {
        let mockApi = MockAuthApi()
        mockApi.signOutError = NSError(domain: "test", code: 1)
        let dataSource = InMemoryAuthDataSource()
        await dataSource.save(AuthData(token: "token", userId: "user"))
        let repository = AuthRepositoryImpl(api: mockApi, dataSource: dataSource)

        await repository.logout()

        let cached = await dataSource.load()
        XCTAssertNil(cached)
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

private final class MockAuthApi: AuthApi, @unchecked Sendable {
    var loginCalled = false
    var shouldThrow = false

    var restoreSessionCalled = false
    /// `nil` means "not stubbed" — defaults to returning no restorable session.
    var restoreSessionResult: Result<AuthDto?, Error>?
    var signOutCalled = false
    var signOutError: Error?

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

    func restoreSession() async throws -> AuthDto? {
        restoreSessionCalled = true
        switch restoreSessionResult {
        case .success(let dto):
            return dto
        case .failure(let error):
            throw error
        case nil:
            return nil
        }
    }

    func signOut() async throws {
        signOutCalled = true
        if let signOutError { throw signOutError }
    }
}
