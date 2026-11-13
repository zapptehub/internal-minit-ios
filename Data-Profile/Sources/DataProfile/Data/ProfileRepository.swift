/// Public boundary for the rest of the app.
public protocol ProfileRepository: Sendable {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws
    func updateName(userId: String, name: String) async throws
    func fetchProfile(userId: String) async throws -> ProfileData?
}
