import CoreNetworking

/// Composition root for profile data.
///
/// Builds `HttpProfileRepository`. `dataBackend` must be `http`; the app
/// rejects every other id before it constructs this module. Surrounding
/// whitespace is ignored.
public final class ProfileDataModule {
    private let repository: HttpProfileRepository

    public init(dataBackend: String, networkClient: any NetworkClient) {
        let id = dataBackend.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(id == "http", "ProfileDataModule only builds the http repository")
        self.repository = HttpProfileRepository(client: networkClient)
    }

    public func makeProfileRepository() -> ProfileRepository { repository }
}
