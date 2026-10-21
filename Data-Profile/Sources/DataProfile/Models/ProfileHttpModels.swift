/// `GET` and `PATCH /v1/me` body. Six keys, including `avatarUrl`.
struct ProfileResponse: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let surname: String
    let email: String
    let loyaltyCardId: String?
    let avatarUrl: String?

    func toModel() -> ProfileData {
        ProfileData(name: name, surname: surname, email: email, avatarUrl: avatarUrl)
    }
}

/// `PATCH /v1/me` when saving name, surname, and email. No other keys.
struct ProfilePatchBody: Encodable, Equatable, Sendable {
    let name: String
    let surname: String
    let email: String
}

/// `PATCH /v1/me` when updating the name only. Omitted fields stay on the server.
struct ProfileNamePatchBody: Encodable, Equatable, Sendable {
    let name: String
}
