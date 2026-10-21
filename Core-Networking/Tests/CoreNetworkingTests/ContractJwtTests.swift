import CoreNetworkingTestUtilities
import Foundation
import XCTest

/// Offline check for `ContractJwt.token`. An empty subject, or one longer than
/// 128 characters, trips the precondition, so this stays inside that range.
final class ContractJwtTests: XCTestCase {
    func testTokenHasThreeSegmentsAlgNoneEmptySignatureClaimsAndSubLength() throws {
        let subject = "contract-subject"
        let issued = 1_700_000_000
        let token = ContractJwt.token(subject: subject, now: Date(timeIntervalSince1970: TimeInterval(issued)))
        try assertShape(token, subject: subject, issued: issued)

        let longest = String(repeating: "a", count: 128)
        let longToken = ContractJwt.token(
            subject: longest,
            now: Date(timeIntervalSince1970: TimeInterval(issued))
        )
        try assertShape(longToken, subject: longest, issued: issued)
        XCTAssertEqual(longest.count, 128)
    }

    private func assertShape(_ token: String, subject: String, issued: Int) throws {
        let segments = token.components(separatedBy: ".")
        XCTAssertEqual(segments.count, 3, token)
        XCTAssertEqual(segments[2], "", token)
        XCTAssertFalse(segments[0].isEmpty, token)
        XCTAssertFalse(segments[1].isEmpty, token)

        let header = try jsonObject(segments[0])
        XCTAssertEqual(Set(header.keys), ["alg", "typ"])
        XCTAssertEqual(header["alg"] as? String, "none")
        XCTAssertEqual(header["typ"] as? String, "JWT")
        XCTAssertNil(header["kid"])

        let claims = try jsonObject(segments[1])
        XCTAssertEqual(
            Set(claims.keys),
            ["iss", "aud", "sub", "iat", "auth_time", "exp"]
        )
        XCTAssertEqual(claims["iss"] as? String, "https://securetoken.google.com/minit-dev-bfc4e")
        XCTAssertEqual(claims["iss"] as? String, ContractJwt.issuer)
        XCTAssertEqual(claims["aud"] as? String, "minit-dev-bfc4e")
        XCTAssertEqual(claims["aud"] as? String, ContractJwt.projectID)
        let sub = try XCTUnwrap(claims["sub"] as? String)
        XCTAssertEqual(sub, subject)
        XCTAssertFalse(sub.isEmpty)
        XCTAssertEqual(sub.count, subject.count)
        XCTAssertLessThanOrEqual(sub.count, 128)
        XCTAssertEqual(claims["iat"] as? Int, issued)
        XCTAssertEqual(claims["auth_time"] as? Int, issued)
        XCTAssertEqual(claims["exp"] as? Int, issued + 3_600)
    }

    private func jsonObject(_ segment: String) throws -> [String: Any] {
        let data = try base64URLDecoded(segment)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    private func base64URLDecoded(_ value: String) throws -> Data {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - (base64.count % 4)) % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: padding))
        }
        return try XCTUnwrap(Data(base64Encoded: base64))
    }
}
