public struct AuthData: Equatable {
    public let token: String
    public let userId: String

    public init(token: String, userId: String) {
        self.token = token
        self.userId = userId
    }
}

public struct AuthDto: Codable {
    public let accessToken: String
    public let userId: String
}

public extension AuthDto {
    func toModel() -> AuthData {
        AuthData(token: accessToken, userId: userId)
    }
}

public enum AuthState: Equatable {
    case idle
    case loading
    case authenticated(AuthData)
    case error(String)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var authData: AuthData? {
        if case .authenticated(let data) = self { return data }
        return nil
    }

    public var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }
}
