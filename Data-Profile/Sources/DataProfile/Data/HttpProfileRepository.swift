import CoreNetworking

/// HTTP `ProfileRepository`.
///
/// `GET /v1/me` inserts the caller's row. `saveProfile` and `updateName`
/// perform that GET before `PATCH`, because a PATCH before the first GET is
/// 404. The token subject selects the row. `userId` is not sent.
///
/// `saveProfile` writes `name`, `surname`, and `email` only. `updateName`
/// writes `name` only. Nothing in the app calls `saveProfile`.
final class HttpProfileRepository: ProfileRepository {
    private let client: any NetworkClient

    init(client: any NetworkClient) {
        self.client = client
    }

    func saveProfile(userId _: String, name: String, surname: String, email: String) async throws {
        _ = try await readMe()
        try await patchMe(ProfilePatchBody(name: name, surname: surname, email: email))
    }

    func updateName(userId _: String, name: String) async throws {
        _ = try await readMe()
        try await patchMe(ProfileNamePatchBody(name: name))
    }

    func fetchProfile(userId _: String) async throws -> ProfileData? {
        try await readMe().toModel()
    }

    /// `PATCH /v1/me`. The response is the updated profile; callers ignore it.
    private func patchMe<Body: Encodable>(_ body: Body) async throws {
        let _: ProfileResponse = try await client.request(Self.me, method: .PATCH, body: body)
    }

    private func readMe() async throws -> ProfileResponse {
        try await client.request(Self.me, method: .GET)
    }

    private static let me = "/v1/me"
}
