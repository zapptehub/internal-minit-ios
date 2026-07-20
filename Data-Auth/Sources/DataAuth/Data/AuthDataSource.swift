public protocol AuthDataSource: Sendable {
    func load() async -> AuthData?
    func save(_ data: AuthData) async
    func clear() async
}

public actor InMemoryAuthDataSource: AuthDataSource {
    private var stored: AuthData?

    public init() {}

    public func load() async -> AuthData? { stored }

    public func save(_ data: AuthData) async { stored = data }

    public func clear() async { stored = nil }
}
