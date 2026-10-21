import Foundation

public enum ContractFixturesError: Error, LocalizedError, CustomStringConvertible {
    case missing(String)
    case notUTF8(String)

    public var description: String {
        switch self {
        case .missing(let message), .notUTF8(let message):
            return message
        }
    }

    public var errorDescription: String? { description }
}

/// Copies of minit-api `contract/` at `a30a082`.
///
/// Tests load these from this module's bundle. They do not read a sibling checkout.
public enum ContractFixtures {
    /// Same order as `contract.sha256`.
    public static let names: [String] = [
        "home.json",
        "notifications.json",
        "profile.json",
        "profile-linked.json",
        "loyalty-card.json",
        "lookup-available.json",
        "lookup-yours.json",
        "lookup-registered.json",
        "points-history.json",
        "points-history-page.json",
        "already-registered.json",
        "already-linked.json",
        "not-found.json",
        "invalid-code.json",
        "invalid-data.json",
        "bad-request.json",
        "unauthenticated.json",
        "method-not-allowed.json",
    ]

    /// Raw bytes of `contract/<name>`. `name` is a file name such as `home.json`.
    public static func bytes(_ name: String) throws -> Data {
        let url = try contractDirectory.appendingPathComponent(name, isDirectory: false)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ContractFixturesError.missing("contract/\(name) is missing")
        }
    }

    public static func text(_ name: String) throws -> String {
        let data = try bytes(name)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ContractFixturesError.notUTF8("contract/\(name) is not UTF-8")
        }
        return text
    }

    /// File names actually present in the copied `contract/` directory.
    public static var bundledFileNames: Set<String> {
        get throws {
            let urls = try FileManager.default.contentsOfDirectory(
                at: try contractDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            var names = Set<String>()
            for url in urls {
                let isFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile
                if isFile == false { continue }
                names.insert(url.lastPathComponent)
            }
            return names
        }
    }

    /// Android `contract.sha256`, which records minit-api `a30a082`.
    public static var sha256Manifest: String {
        get throws {
            guard let url = Bundle.module.url(forResource: "contract", withExtension: "sha256") else {
                throw ContractFixturesError.missing("contract.sha256 is missing")
            }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw ContractFixturesError.missing("contract.sha256 is missing")
            }
            guard let text = String(data: data, encoding: .utf8) else {
                throw ContractFixturesError.notUTF8("contract.sha256 is not UTF-8")
            }
            return text
        }
    }

    private static var contractDirectory: URL {
        get throws {
            guard let root = Bundle.module.resourceURL else {
                throw ContractFixturesError.missing("contract fixture bundle has no resource URL")
            }
            let directory = root.appendingPathComponent("contract", isDirectory: true)
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw ContractFixturesError.missing("contract/ is missing from the fixture bundle")
            }
            return directory
        }
    }
}
