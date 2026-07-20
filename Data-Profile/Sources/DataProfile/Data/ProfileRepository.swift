/// Public boundary for the rest of the app — no Firebase types appear here or in any
/// consumer.
public protocol ProfileRepository: Sendable {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws
    func updateName(userId: String, name: String) async throws
    func fetchProfile(userId: String) async throws -> ProfileData?
}

public final class ProfileRepositoryImpl: ProfileRepository {
    private let api: ProfileApi

    public init(api: ProfileApi) {
        self.api = api
    }

    public func saveProfile(userId: String, name: String, surname: String, email: String) async throws {
        try await api.saveProfile(
            userId: userId,
            profile: ProfileDto(name: name, surname: surname, email: email)
        )
    }

    public func updateName(userId: String, name: String) async throws {
        try await api.updateName(userId: userId, name: name)
    }

    public func fetchProfile(userId: String) async throws -> ProfileData? {
        try await api.fetchProfile(userId: userId)?.toModel()
    }
}
