import XCTest
@testable import FeatureOnboarding

final class OnboardingTrimTests: XCTestCase {
    func testOnboardingTrimmedAppliesTheSharedNameAndCodeVectors() {
        let cases: [(String, String)] = [
            ("  Iveta  ", "Iveta"),
            ("\nIveta\t", "Iveta"),
            (" \r\n\tIveta\t\n ", "Iveta"),
            ("\u{00A0}Iveta\u{00A0}", "Iveta"),
            ("\u{2028}Iveta\u{2028}", "Iveta"),
            ("\u{2029}Iveta\u{2029}", "Iveta"),
            ("\u{000B}Iveta\u{000C}", "Iveta"),
            ("\u{0085}Iveta\u{0085}", "Iveta"),
            ("\u{001C}Iveta\u{001C}", "Iveta"),
            ("\u{001D}Iveta\u{001D}", "Iveta"),
            ("\u{001E}Iveta\u{001E}", "Iveta"),
            ("\u{001F}Iveta\u{001F}", "Iveta"),
            ("\u{007F}Iveta\u{007F}", "Iveta"),
            ("\u{0090}Iveta\u{0090}", "Iveta"),
            ("", ""),
            (" \n\t ", ""),
            ("\u{0085}", ""),
            ("\u{001C}\u{001D}\u{001E}\u{001F}", ""),
            ("\u{007F}", ""),
            ("\u{0090}", ""),
            ("Ive\u{0085}ta", "Ive\u{0085}ta"),
            ("Ive\u{001C}ta", "Ive\u{001C}ta"),
            ("Ive\u{007F}ta", "Ive\u{007F}ta"),
            ("Ive\u{0090}ta", "Ive\u{0090}ta"),
            ("  ab c  ", "ab c"),
            ("Mi NiT", "Mi NiT"),
            ("\tMi NiT\n", "Mi NiT"),
            ("\u{0085}MINIT-NL\u{0085}", "MINIT-NL"),
            ("\u{001C}MINIT\u{001C}", "MINIT"),
            ("\u{007F}MINIT\u{007F}", "MINIT"),
            ("\u{0090}MINIT\u{0090}", "MINIT"),
            ("MI\u{0085}NIT", "MI\u{0085}NIT"),
            ("MI\u{001C}NIT", "MI\u{001C}NIT"),
            ("MI\u{007F}NIT", "MI\u{007F}NIT"),
            ("MI\u{0090}NIT", "MI\u{0090}NIT"),
            ("\u{007F}A\u{0085}B\u{001C}C\u{007F}", "A\u{0085}B\u{001C}C"),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(raw.onboardingTrimmed, expected, raw.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))
        }
    }

    func testOnboardingTrimmedRemovesAnEdgeCharacterOnlyWhenItIsZsZlZpOrCc() {
        for code in 0...0xFFFF {
            guard let scalar = Unicode.Scalar(code) else { continue }
            let removes: Bool
            switch scalar.properties.generalCategory {
            case .spaceSeparator, .lineSeparator, .paragraphSeparator, .control:
                removes = true
            default:
                removes = false
            }
            let wrapped = String(scalar) + "+" + String(scalar)
            let result = wrapped.onboardingTrimmed
            let label = String(format: "U+%04X", code)
            if removes {
                XCTAssertEqual(result, "+", label)
            } else {
                XCTAssertEqual(result, wrapped, label)
            }
        }
    }
}
