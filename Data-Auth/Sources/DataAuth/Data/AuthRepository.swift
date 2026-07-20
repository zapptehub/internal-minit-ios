public protocol AuthRepository: Sendable {
    func login(email: String, password: String) async throws -> AuthData
    func logout() async
    /// Returns the current session, restoring it from the backend's own persisted identity
    /// when the in-memory cache is empty (e.g. after a relaunch). Returns `nil` when there
    /// is definitely no valid session (never logged in, or the persisted identity was
    /// revoked/disabled/deleted). Throws only when validity could not be determined (e.g.
    /// a network failure during restoration) — callers should treat that as "unknown, retry
    /// later" rather than "signed out".
    func currentSession() async throws -> AuthData?
    func checkEmailExists(email: String) async throws -> Bool
    func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthData
    func sendVerificationCode(email: String) async throws
    func confirmPasswordReset(email: String, code: String) async throws
}

public actor AuthRepositoryImpl: AuthRepository {
    private let api: AuthApi
    private let dataSource: AuthDataSource

    public init(api: AuthApi, dataSource: AuthDataSource) {
        self.api = api
        self.dataSource = dataSource
    }

    public func login(email: String, password: String) async throws -> AuthData {
        let dto = try await api.login(email: email, password: password)
        let authData = dto.toModel()
        await dataSource.save(authData)
        return authData
    }

    public func logout() async {
        // Clear the local cache first so the app can treat the user as signed out
        // immediately, regardless of whether the remote sign-out below succeeds — logout
        // is authoritative on this side even if, say, the network call fails.
        await dataSource.clear()
        try? await api.signOut()
    }

    public func currentSession() async throws -> AuthData? {
        if let cached = await dataSource.load() {
            return cached
        }

        guard let restored = try await api.restoreSession() else {
            return nil
        }

        let authData = restored.toModel()
        await dataSource.save(authData)
        return authData
    }

    public func checkEmailExists(email: String) async throws -> Bool {
        try await api.checkEmailExists(email: email)
    }

    public func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthData {
        let dto = try await api.register(email: email, password: password, marketingOptIn: marketingOptIn)
        let authData = dto.toModel()
        await dataSource.save(authData)
        return authData
    }

    public func sendVerificationCode(email: String) async throws {
        try await api.sendVerificationCode(email: email)
    }

    public func confirmPasswordReset(email: String, code: String) async throws {
        try await api.confirmPasswordReset(email: email, code: code)
    }
}
