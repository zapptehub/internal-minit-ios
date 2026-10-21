import CoreNetworkingTestUtilities
import CryptoKit
import Foundation
import XCTest

final class ContractFixturesTests: XCTestCase {
    func testContractFixturesMatchTheRecordedSHA256() throws {
        XCTAssertEqual(ContractFixtures.names.count, 18)
        XCTAssertEqual(Set(ContractFixtures.names).count, ContractFixtures.names.count)
        let manifestText = try ContractFixtures.sha256Manifest
        XCTAssertTrue(manifestText.contains("a30a082"))

        let bundled = try ContractFixtures.bundledFileNames
        XCTAssertEqual(Set(ContractFixtures.names), bundled)
        guard bundled == Set(ContractFixtures.names) else { return }

        let manifest = try manifestEntries(manifestText)
        XCTAssertEqual(
            ContractFixtures.names,
            manifest.map(\.name),
            "ContractFixtures.names order vs contract.sha256"
        )

        for entry in manifest {
            let data = try ContractFixtures.bytes(entry.name)
            XCTAssertEqual(entry.digest, sha256Hex(data), entry.name)
            XCTAssertFalse(data.isEmpty, entry.name)
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data), entry.name)
        }
    }

    func testHomeAndNotificationsDecodeWithoutForbiddenKeys() throws {
        for name in ["home.json", "notifications.json"] {
            let object = try jsonObject(name)
            XCTAssertEqual(forbiddenContractKeys(in: object), [], name)
        }
    }

    /// Keys are compared after lowercasing and dropping every character that is not a letter or digit.
    func testForbiddenKeyWalkRejectsNormalizedOwnerEmailAndSurnameKeys() throws {
        let json = """
        {
          "owner": 1,
          "ownerUserId": 2,
          "user_id": 3,
          "nested": [{"E-mail": "a", "sur-name": "b", "title": "ok"}]
        }
        """
        let element = try JSONSerialization.jsonObject(with: Data(json.utf8))
        XCTAssertEqual(
            Set(forbiddenContractKeys(in: element)),
            ["owner", "ownerUserId", "user_id", "E-mail", "sur-name"]
        )
    }

    func testProfileFixturesHaveSixKeysInOrderAndDefaultAvatarURL() throws {
        let keys = ["id", "name", "surname", "email", "loyaltyCardId", "avatarUrl"]
        for name in ["profile.json", "profile-linked.json"] {
            XCTAssertEqual(orderedTopLevelKeys(in: try ContractFixtures.text(name)), keys, name)
            let profile = try jsonObject(name)
            XCTAssertEqual(Set(profile.keys), Set(keys), name)
            let avatarURL = try XCTUnwrap(profile["avatarUrl"] as? String, name)
            XCTAssertTrue(avatarURL.hasSuffix("/v1/media/avatars/default.webp"), name)
        }
    }

    /// `@` is allowed only in the `email` string of a profile fixture.
    func testNoAtSignOutsideProfileEmail() throws {
        for name in ContractFixtures.names {
            let value = try JSONSerialization.jsonObject(with: try ContractFixtures.bytes(name))
            XCTAssertEqual(atSignPaths(in: value, fileName: name), [], name)
        }

        let profileEmail = try JSONSerialization.jsonObject(
            with: Data(#"{"email":"a@b.c","name":"Iveta"}"#.utf8)
        )
        XCTAssertEqual(atSignPaths(in: profileEmail, fileName: "profile.json"), [])
        XCTAssertEqual(atSignPaths(in: profileEmail, fileName: "profile-linked.json"), [])

        let profileName = try JSONSerialization.jsonObject(
            with: Data(#"{"email":"a@b.c","name":"a@b"}"#.utf8)
        )
        XCTAssertEqual(atSignPaths(in: profileName, fileName: "profile.json"), ["$.name"])

        let homeTitle = try JSONSerialization.jsonObject(
            with: Data(#"{"title":"a@b"}"#.utf8)
        )
        XCTAssertEqual(atSignPaths(in: homeTitle, fileName: "home.json"), ["$.title"])

        let nested = try JSONSerialization.jsonObject(
            with: Data(#"{"items":[{"title":"a@b"}]}"#.utf8)
        )
        XCTAssertEqual(atSignPaths(in: nested, fileName: "home.json"), ["$.items[0].title"])
    }

    func testLoyaltyCardFixtureIs3210SilverWithoutOwner() throws {
        let card = try jsonObject("loyalty-card.json")
        XCTAssertEqual(card["points"] as? Int, 3210)
        XCTAssertEqual(card["tierId"] as? String, "silver")
        XCTAssertEqual(forbiddenContractKeys(in: card), [])
    }

    func testLookupFixturesAreCodeAndStatusOnly() throws {
        for name in ["lookup-available.json", "lookup-yours.json", "lookup-registered.json"] {
            let lookup = try jsonObject(name)
            XCTAssertEqual(Set(lookup.keys), ["code", "status"], name)
        }
    }

    func testPointsHistoryFixturesDecodeCursorsAndReasonStrings() throws {
        let first = try jsonObject("points-history.json")
        let page = try jsonObject("points-history-page.json")

        XCTAssertTrue(first["nextCursor"] is NSNull)
        let cursor = try XCTUnwrap(page["nextCursor"] as? String)
        XCTAssertFalse(cursor.isEmpty)

        try assertReasonStrings(first)
        try assertReasonStrings(page)
    }

    private func assertReasonStrings(_ page: [String: Any]) throws {
        let items = try XCTUnwrap(page["items"] as? [[String: Any]])
        XCTAssertFalse(items.isEmpty)
        for item in items {
            let reason = try XCTUnwrap(item["reason"] as? [String: Any])
            XCTAssertEqual(reason["en"] as? String, "Starting balance")
            XCTAssertEqual(reason["sk"] as? String, "Počiatočný zostatok")
            XCTAssertEqual(reason["hu"] as? String, "Kezdő egyenleg")
        }
    }

    private func jsonObject(_ name: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: try ContractFixtures.bytes(name))
        return try XCTUnwrap(object as? [String: Any])
    }

    private func manifestEntries(_ manifestText: String) throws -> [(digest: String, name: String)] {
        let regex = try NSRegularExpression(pattern: #"^([0-9a-f]{64})  (\S+\.json)$"#)
        var entries: [(digest: String, name: String)] = []
        for rawLine in manifestText.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let digestRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line) else {
                XCTFail("Bad manifest line: \(line)")
                continue
            }
            entries.append((String(line[digestRange]), String(line[nameRange])))
        }
        return entries
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { byte in
            let hex = String(byte, radix: 16)
            return hex.count == 1 ? "0" + hex : hex
        }.joined()
    }

    /// Source order of the root object's keys. `JSONSerialization` dictionaries do not keep order.
    private func orderedTopLevelKeys(in text: String) -> [String] {
        var keys: [String] = []
        var depth = 0
        var inString = false
        var escape = false
        var string = ""
        var pendingKey: String?
        for character in text {
            if inString {
                if escape {
                    string.append(character)
                    escape = false
                    continue
                }
                if character == "\\" {
                    escape = true
                    continue
                }
                if character == "\"" {
                    inString = false
                    if depth == 1 {
                        pendingKey = string
                    }
                    continue
                }
                string.append(character)
                continue
            }
            switch character {
            case "\"":
                inString = true
                string = ""
            case "{", "[":
                depth += 1
                pendingKey = nil
            case "}", "]":
                depth -= 1
                pendingKey = nil
            case ":":
                if depth == 1, let key = pendingKey {
                    keys.append(key)
                }
                pendingKey = nil
            default:
                if !character.isWhitespace {
                    pendingKey = nil
                }
            }
        }
        return keys
    }

    /// Lowercased, with every character that is not a letter or digit removed.
    private func normalizedContractKey(_ key: String) -> String {
        String(key.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private let forbiddenNormalizedKeys: Set<String> = [
        "owner",
        "owneruserid",
        "userid",
        "email",
        "surname",
    ]

    private func forbiddenContractKeys(in value: Any) -> [String] {
        var found: [String] = []
        func walk(_ value: Any) {
            if let object = value as? [String: Any] {
                for (key, nested) in object {
                    if forbiddenNormalizedKeys.contains(normalizedContractKey(key)) {
                        found.append(key)
                    }
                    walk(nested)
                }
            } else if let array = value as? [Any] {
                array.forEach(walk)
            }
        }
        walk(value)
        return found
    }

    /// `@` is allowed only in the `email` string of `profile.json` and `profile-linked.json`.
    private func atSignPaths(in value: Any, fileName: String) -> [String] {
        let allowProfileEmail = fileName == "profile.json" || fileName == "profile-linked.json"
        var found: [String] = []
        func walk(_ value: Any, _ path: String, _ key: String?) {
            if let object = value as? [String: Any] {
                for (childKey, nested) in object {
                    walk(nested, "\(path).\(childKey)", childKey)
                }
            } else if let array = value as? [Any] {
                for (index, nested) in array.enumerated() {
                    walk(nested, "\(path)[\(index)]", nil)
                }
            } else if let text = value as? String, text.contains("@") {
                if allowProfileEmail, key == "email" { return }
                found.append(path)
            }
        }
        walk(value, "$", nil)
        return found.sorted()
    }
}
