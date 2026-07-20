public struct ProfileData: Equatable, Sendable {
    public let name: String
    public let surname: String
    public let email: String

    public init(name: String, surname: String, email: String) {
        self.name = name
        self.surname = surname
        self.email = email
    }
}

public struct ProfileDto: Codable, Sendable {
    public let name: String
    public let surname: String
    public let email: String

    public init(name: String, surname: String, email: String) {
        self.name = name
        self.surname = surname
        self.email = email
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case surname
        case email
    }

    /// Profile records may be created incrementally by other user flows. Keep the public
    /// domain shape non-optional while decoding absent legacy fields as empty strings.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        surname = try container.decodeIfPresent(String.self, forKey: .surname) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
    }
}

public extension ProfileDto {
    func toModel() -> ProfileData {
        ProfileData(name: name, surname: surname, email: email)
    }
}

public extension ProfileData {
    func toDto() -> ProfileDto {
        ProfileDto(name: name, surname: surname, email: email)
    }
}
