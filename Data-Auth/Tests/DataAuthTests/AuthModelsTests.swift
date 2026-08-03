import XCTest
@testable import DataAuth

final class AuthModelsTests: XCTestCase {
    // MARK: - AuthDto.toModel()

    func testAuthDtoToModelMapsFieldsDirectly() {
        let dto = AuthDto(accessToken: "token-123", userId: "user-456")

        let model = dto.toModel()

        XCTAssertEqual(model.token, "token-123")
        XCTAssertEqual(model.userId, "user-456")
    }

    // MARK: - AuthState.isLoading

    func testIsLoadingIsTrueOnlyForLoadingCase() {
        XCTAssertTrue(AuthState.loading.isLoading)
        XCTAssertFalse(AuthState.idle.isLoading)
        XCTAssertFalse(AuthState.authenticated(AuthData(token: "t", userId: "u")).isLoading)
        XCTAssertFalse(AuthState.error("failed").isLoading)
    }

    // MARK: - AuthState.authData

    func testAuthDataReturnsWrappedValueOnlyForAuthenticatedCase() {
        let data = AuthData(token: "t", userId: "u")

        XCTAssertEqual(AuthState.authenticated(data).authData, data)
        XCTAssertNil(AuthState.idle.authData)
        XCTAssertNil(AuthState.loading.authData)
        XCTAssertNil(AuthState.error("failed").authData)
    }

    // MARK: - AuthState.errorMessage

    func testErrorMessageReturnsWrappedValueOnlyForErrorCase() {
        XCTAssertEqual(AuthState.error("something failed").errorMessage, "something failed")
        XCTAssertNil(AuthState.idle.errorMessage)
        XCTAssertNil(AuthState.loading.errorMessage)
        XCTAssertNil(AuthState.authenticated(AuthData(token: "t", userId: "u")).errorMessage)
    }

    // MARK: - AuthState.Equatable

    func testAuthStateEqualityComparesAssociatedValues() {
        XCTAssertEqual(
            AuthState.authenticated(AuthData(token: "t", userId: "u")),
            AuthState.authenticated(AuthData(token: "t", userId: "u"))
        )
        XCTAssertNotEqual(
            AuthState.authenticated(AuthData(token: "t", userId: "u")),
            AuthState.authenticated(AuthData(token: "other", userId: "u"))
        )
        XCTAssertNotEqual(AuthState.idle, AuthState.loading)
    }
}
