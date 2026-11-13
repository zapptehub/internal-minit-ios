import CoreNetworking
import Foundation

/// Home document for the signed-in caller.
///
/// `HttpHomeRepository` decodes `GET /v1/home`. The screen shows the bundled
/// sample (`HomeCatalog.firebase`) while that load is in flight. The first
/// failure is a visible retry. A later failure keeps the catalog already on
/// screen. A pull-to-refresh failure also keeps that catalog and surfaces a
/// non-blocking error.
public protocol HomeRepository: Sendable {
    func load() async throws -> HomeCatalog
}

/// Bundled sample catalog. Does not call the network.
///
/// Previews and tests use this. The home screen also starts on the same
/// catalog while `GET /v1/home` is in flight. It is not a data backend.
public struct SampleHomeRepository: HomeRepository, Sendable {
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
/// `http` is the only id. The app rejects every other id before calling this.
/// Surrounding whitespace is ignored.
public enum HomeRepositoryFactory {
    public static func make(dataBackend: String, networkClient: any NetworkClient) -> any HomeRepository {
        let id = dataBackend.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(id == "http", "HomeRepositoryFactory only builds the http repository")
        return HttpHomeRepository(client: networkClient)
    }
}
