/// Boundary to the profile backend — one-shot request/response only (no live listeners), to
/// keep behavior close to a real REST backend. The concrete implementation
/// (`FirebaseProfileApiImpl`) is added in a later step; this protocol is the only thing
/// `ProfileRepository` and callers outside `Data-Profile` ever depend on.
public protocol ProfileApi: Sendable {
    func saveProfile(userId: String, profile: ProfileDto) async throws
    func updateName(userId: String, name: String) async throws
    func fetchProfile(userId: String) async throws -> ProfileDto?
}
