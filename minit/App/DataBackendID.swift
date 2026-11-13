import Foundation

/// Resolves the `MinitDataBackend` plist value. `http` is the only id.
///
/// This does not read the bundle and does not trap. Startup calls it once
/// and `fatalError`s on `.failure`.
func resolveDataBackendID(_ raw: String) -> Result<String, DataBackendIDError> {
    let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if id == "http" {
        return .success(id)
    }
    if id.isEmpty || id.hasPrefix("$(") {
        return .failure(.missingOrUnexpanded)
    }
    if id == "firebase" {
        return .failure(.removedFirebase)
    }
    return .failure(.unknown(id))
}

enum DataBackendIDError: Error, Equatable, CustomStringConvertible {
    case missingOrUnexpanded
    case removedFirebase
    case unknown(String)

    var description: String {
        switch self {
        case .missingOrUnexpanded:
            return "MinitDataBackend is missing or unexpanded in Info.plist. The only supported id is http."
        case .removedFirebase:
            return "MinitDataBackend \"firebase\" was removed. Store, Debug, and Internal builds use http."
        case .unknown(let id):
            return "Unknown data backend \"\(id)\". The only supported id is http."
        }
    }
}
