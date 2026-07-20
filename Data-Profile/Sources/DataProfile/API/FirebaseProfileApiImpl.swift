import FirebaseDatabase

/// Real `ProfileApi` implementation backed by Firebase Realtime Database. Uses one-shot
/// `getData` and partial `updateChildValues` calls only — no live listeners or full-user-node
/// writes. This is the sole place in `Data-Profile` that imports `FirebaseDatabase`.
public final class FirebaseProfileApiImpl: ProfileApi {
    public init() {}

    public func saveProfile(userId: String, profile: ProfileDto) async throws {
        // Multi-path update rather than a full-node `setValue`, so this can never clobber the
        // other or future sibling keys on the same node.
        try await userReference(userId: userId).updateChildValues([
            "name": profile.name,
            "surname": profile.surname,
            "email": profile.email
        ])
    }

    public func updateName(userId: String, name: String) async throws {
        try await userReference(userId: userId).updateChildValues(["name": name])
    }

    public func fetchProfile(userId: String) async throws -> ProfileDto? {
        let snapshot = try await userReference(userId: userId).getData()
        guard snapshot.exists(), snapshot.value != nil else {
            return nil
        }
        return try snapshot.data(as: ProfileDto.self)
    }

    private func userReference(userId: String) -> DatabaseReference {
        Database.database().reference().child("users").child(userId)
    }
}
