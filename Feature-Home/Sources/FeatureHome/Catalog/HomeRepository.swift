import CoreNetworking
import Foundation

/// Home document for the signed-in caller.
///
/// Firebase returns the sample catalog and does not call the network. HTTP
/// decodes `GET /v1/home`. The screen shows the sample while that load is in
/// flight. The first failure is a visible retry. A later failure keeps the
/// catalog already on screen. A pull-to-refresh failure also keeps that
/// catalog and surfaces a non-blocking error.
public protocol HomeRepository: Sendable {
    func load() async throws -> HomeCatalog
}

public struct FirebaseHomeRepository: HomeRepository, Sendable {
    public init() {}

    public func load() async throws -> HomeCatalog {
        .firebase
    }
}

public struct HttpHomeRepository: HomeRepository, Sendable {
    private let client: any NetworkClient

    public init(client: any NetworkClient) {
        self.client = client
    }

    public func load() async throws -> HomeCatalog {
        let document: HomeDocument = try await client.request(Self.path, method: .GET)
        return HomeCatalogMapper.catalog(document)
    }

    static let path = "/v1/home"
}

/// Builds the home repository for a plist backend id.
///
/// `http` is the only id that constructs `HttpHomeRepository`. `firebase`
/// returns the sample. Any other id fails, matching the profile and loyalty modules.
public enum HomeRepositoryFactory {
    public static func make(dataBackend: String, networkClient: any NetworkClient) -> any HomeRepository {
        let id = dataBackend.trimmingCharacters(in: .whitespacesAndNewlines)
        switch id {
        case "http":
            return HttpHomeRepository(client: networkClient)
        case "firebase":
            return FirebaseHomeRepository()
        default:
            fatalError("Unknown data backend \"\(id)\"")
        }
    }
}
