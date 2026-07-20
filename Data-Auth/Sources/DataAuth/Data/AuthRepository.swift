public protocol AuthRepository: Sendable {
    func login(email: String, password: String) async throws -> AuthData
    func logout() async
    func currentSession() async -> AuthData?
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
        await dataSource.clear()
    }

    public func currentSession() async -> AuthData? {
        await dataSource.load()
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
