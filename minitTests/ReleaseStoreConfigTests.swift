import XCTest

/// Committed Release settings for the store build.
///
/// Resolved values are also checked by `scripts/check-backend-build-settings.sh`.
/// This test reads the xcconfig so the unit suite fails if Release drifts back
/// to Firebase or onto the Access-protected mock path.
final class ReleaseStoreConfigTests: XCTestCase {
    func testReleaseUsesThePublicHTTPAPIWithEmptyAccessAndDemoOff() throws {
        let url = repositoryRoot().appendingPathComponent("Config/Release.xcconfig")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path))
        let text = try String(contentsOf: url, encoding: .utf8)
        let settings = assignments(in: text)

        XCTAssertEqual(settings["MINIT_DATA_BACKEND"], "http")
        XCTAssertEqual(settings["MINIT_API_BASE_URL"], "https:/$()/api.zappte.eu/min")
        XCTAssertEqual(settings["MINIT_DEMO_ENABLED"], "NO")
        XCTAssertEqual(settings["CF_ACCESS_CLIENT_ID"], "")
        XCTAssertEqual(settings["CF_ACCESS_CLIENT_SECRET"], "")

        let code = text.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty && !trimmed.hasPrefix("//")
            }
            .joined(separator: "\n")
        XCTAssertFalse(code.contains("firebase"))
        XCTAssertFalse(code.contains("api.minit.app"))
        XCTAssertFalse(code.contains("/mock"))
        XCTAssertFalse(code.contains("Local.xcconfig"))
        XCTAssertFalse(code.contains("Secrets.xcconfig"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assignments(in text: String) -> [String: String] {
        var settings: [String: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("//") || line.hasPrefix("#") {
                continue
            }
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            settings[String(key)] = String(value)
        }
        return settings
    }
}
