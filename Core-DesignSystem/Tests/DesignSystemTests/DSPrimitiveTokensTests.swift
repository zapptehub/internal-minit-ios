import CoreGraphics
import XCTest
@testable import DesignSystem

final class DSPrimitiveTokensTests: XCTestCase {
    func testEveryColorMatchesTheModeOneExport() {
        XCTAssertEqual(DSPrimitiveSource.modeName, "Mode 1")
        XCTAssertEqual(
            [
                "color.black": ColorContract(0x000000, 1.00, "VariableID:16:61"),
                "color.white": ColorContract(0xFFFFFF, 1.00, "VariableID:16:62"),
                "color.transparent-5": ColorContract(0xFFFFFF, 0.05, "VariableID:16:87"),
                "color.transparent-10": ColorContract(0xFFFFFF, 0.10, "VariableID:2075:428"),
                "color.transparent-15": ColorContract(0xFFFFFF, 0.15, "VariableID:2075:429"),
                "color.minit.50": ColorContract(0xFFFAF5, 1.00, "VariableID:2009:84"),
                "color.minit.100": ColorContract(0xFFE2C4, 1.00, "VariableID:16:5"),
                "color.minit.200": ColorContract(0xFFCA93, 1.00, "VariableID:16:6"),
                "color.minit.300": ColorContract(0xFFCA93, 1.00, "VariableID:16:7"),
                "color.minit.400": ColorContract(0xFF9A31, 1.00, "VariableID:16:8"),
                "color.minit.500": ColorContract(0xFF8200, 1.00, "VariableID:16:9"),
                "color.minit.600": ColorContract(0xCE6900, 1.00, "VariableID:16:10"),
                "color.minit.700": ColorContract(0x9D5000, 1.00, "VariableID:16:11"),
                "color.minit.800": ColorContract(0x6C3700, 1.00, "VariableID:16:12"),
                "color.deep-claret.50": ColorContract(0xFFFAFC, 1.00, "VariableID:2009:86"),
                "color.deep-claret.100": ColorContract(0xF4CBDB, 1.00, "VariableID:16:13"),
                "color.deep-claret.200": ColorContract(0xEA9DBA, 1.00, "VariableID:16:14"),
                "color.deep-claret.300": ColorContract(0xDF6E99, 1.00, "VariableID:16:15"),
                "color.deep-claret.400": ColorContract(0xD54078, 1.00, "VariableID:16:16"),
                "color.deep-claret.500": ColorContract(0xCA1157, 1.00, "VariableID:16:17"),
                "color.deep-claret.600": ColorContract(0xA20E46, 1.00, "VariableID:16:18"),
                "color.deep-claret.700": ColorContract(0x790A34, 1.00, "VariableID:16:19"),
                "color.deep-claret.800": ColorContract(0x510723, 1.00, "VariableID:16:20"),
                "color.deep-claret.850": ColorContract(0x3D051A, 1.00, "VariableID:4117:7331"),
                "color.deep-claret.900": ColorContract(0x280311, 1.00, "VariableID:2009:87"),
                "color.brown.25": ColorContract(0xFFF5EB, 1.00, "VariableID:6177:2482"),
                "color.brown.50": ColorContract(0xD6C9BC, 1.00, "VariableID:6177:2471"),
                "color.brown.100": ColorContract(0xC2B3A4, 1.00, "VariableID:6177:2472"),
                "color.brown.200": ColorContract(0xAD9D8D, 1.00, "VariableID:6177:2473"),
                "color.brown.300": ColorContract(0x85725E, 1.00, "VariableID:6177:2474"),
                "color.brown.400": ColorContract(0x5C462F, 1.00, "VariableID:6177:2475"),
                "color.brown.500": ColorContract(0x331A00, 1.00, "VariableID:6177:2476"),
                "color.brown.600": ColorContract(0x291500, 1.00, "VariableID:6177:2477"),
                "color.brown.700": ColorContract(0x1F1000, 1.00, "VariableID:6177:2478"),
                "color.brown.800": ColorContract(0x140A00, 1.00, "VariableID:6177:2479"),
                "color.deep-green.25": ColorContract(0xE5FCF1, 1.00, "VariableID:6177:2483"),
                "color.deep-green.50": ColorContract(0xCFEADD, 1.00, "VariableID:6177:2484"),
                "color.deep-green.100": ColorContract(0xB9D7C9, 1.00, "VariableID:6177:2485"),
                "color.deep-green.200": ColorContract(0x8DB3A1, 1.00, "VariableID:6177:2486"),
                "color.deep-green.300": ColorContract(0x618E78, 1.00, "VariableID:6177:2487"),
                "color.deep-green.400": ColorContract(0x356A50, 1.00, "VariableID:6177:2488"),
                "color.deep-green.500": ColorContract(0x094528, 1.00, "VariableID:6177:2489"),
                "color.deep-green.600": ColorContract(0x073720, 1.00, "VariableID:6177:2490"),
                "color.deep-green.700": ColorContract(0x052918, 1.00, "VariableID:6177:2491"),
                "color.deep-green.800": ColorContract(0x041C10, 1.00, "VariableID:6177:2492"),
                "color.deep-green.900": ColorContract(0x03150C, 1.00, "VariableID:6177:2493"),
                "color.green.50": ColorContract(0xEBF9F2, 1.00, "VariableID:2009:272"),
                "color.green.100": ColorContract(0xD7F4E6, 1.00, "VariableID:16:21"),
                "color.green.200": ColorContract(0xB0E8CC, 1.00, "VariableID:16:22"),
                "color.green.300": ColorContract(0x88DDB3, 1.00, "VariableID:16:23"),
                "color.green.400": ColorContract(0x61D199, 1.00, "VariableID:16:24"),
                "color.green.500": ColorContract(0x41C885, 1.00, "VariableID:16:25"),
                "color.green.600": ColorContract(0x2E9E66, 1.00, "VariableID:16:26"),
                "color.green.700": ColorContract(0x22774D, 1.00, "VariableID:16:27"),
                "color.green.800": ColorContract(0x174F33, 1.00, "VariableID:16:28"),
                "color.green.900": ColorContract(0x0B281A, 1.00, "VariableID:2009:273"),
                "color.yellow.50": ColorContract(0xFEF8E7, 1.00, "VariableID:2009:274"),
                "color.yellow.100": ColorContract(0xFDF1CE, 1.00, "VariableID:16:29"),
                "color.yellow.200": ColorContract(0xFBE39D, 1.00, "VariableID:16:30"),
                "color.yellow.300": ColorContract(0xF9D66C, 1.00, "VariableID:16:31"),
                "color.yellow.400": ColorContract(0xF7C83B, 1.00, "VariableID:16:32"),
                "color.yellow.500": ColorContract(0xF7CB47, 1.00, "VariableID:16:33"),
                "color.yellow.600": ColorContract(0xC49508, 1.00, "VariableID:16:34"),
                "color.yellow.700": ColorContract(0x937006, 1.00, "VariableID:16:35"),
                "color.yellow.800": ColorContract(0x624A04, 1.00, "VariableID:16:36"),
                "color.yellow.900": ColorContract(0x312502, 1.00, "VariableID:2009:275"),
                "color.red.50": ColorContract(0xFDE7E7, 1.00, "VariableID:2009:276"),
                "color.red.100": ColorContract(0xFCCFCF, 1.00, "VariableID:16:37"),
                "color.red.200": ColorContract(0xF99F9F, 1.00, "VariableID:16:38"),
                "color.red.300": ColorContract(0xF66F6F, 1.00, "VariableID:16:39"),
                "color.red.400": ColorContract(0xF24040, 1.00, "VariableID:16:40"),
                "color.red.500": ColorContract(0xF23A3A, 1.00, "VariableID:16:41"),
                "color.red.600": ColorContract(0xBF0D0D, 1.00, "VariableID:16:42"),
                "color.red.700": ColorContract(0x900909, 1.00, "VariableID:16:43"),
                "color.red.800": ColorContract(0x600606, 1.00, "VariableID:16:44"),
                "color.red.900": ColorContract(0x300303, 1.00, "VariableID:2009:277"),
                "color.grey.50": ColorContract(0xF2F2F2, 1.00, "VariableID:16:88"),
                "color.grey.100": ColorContract(0xE6E6E6, 1.00, "VariableID:16:45"),
                "color.grey.200": ColorContract(0xCCCCCC, 1.00, "VariableID:16:46"),
                "color.grey.300": ColorContract(0xB3B3B3, 1.00, "VariableID:16:47"),
                "color.grey.400": ColorContract(0x999999, 1.00, "VariableID:16:48"),
                "color.grey.500": ColorContract(0x383838, 1.00, "VariableID:16:49"),
                "color.grey.600": ColorContract(0x666666, 1.00, "VariableID:16:50"),
                "color.grey.700": ColorContract(0x4D4D4D, 1.00, "VariableID:16:51"),
                "color.grey.800": ColorContract(0x333333, 1.00, "VariableID:16:52"),
                "color.grey.900": ColorContract(0x1A1A1A, 1.00, "VariableID:2009:278"),
                "color.blue.50": ColorContract(0xEBF4F8, 1.00, "VariableID:2009:279"),
                "color.blue.100": ColorContract(0xD0E3FB, 1.00, "VariableID:16:53"),
                "color.blue.200": ColorContract(0xA1C6F7, 1.00, "VariableID:16:54"),
                "color.blue.300": ColorContract(0x72AAF3, 1.00, "VariableID:16:55"),
                "color.blue.400": ColorContract(0x438EEF, 1.00, "VariableID:16:56"),
                "color.blue.500": ColorContract(0x2C80ED, 1.00, "VariableID:16:57"),
                "color.blue.600": ColorContract(0x105BBC, 1.00, "VariableID:16:58"),
                "color.blue.700": ColorContract(0x0C448D, 1.00, "VariableID:16:59"),
                "color.blue.800": ColorContract(0x082D5E, 1.00, "VariableID:16:60"),
                "color.blue.900": ColorContract(0x04172F, 1.00, "VariableID:2009:280"),
            ],
            DSPrimitiveColor.all.mapValues { token in
                ColorContract(token.rgb, token.opacity, token.sourceID)
            }
        )
        XCTAssertNotEqual(
            DSPrimitiveColor.Minit.tone200.sourceID,
            DSPrimitiveColor.Minit.tone300.sourceID
        )
        XCTAssertLessThan(DSPrimitiveColor.Grey.tone500.rgb, DSPrimitiveColor.Grey.tone400.rgb)
        XCTAssertLessThan(DSPrimitiveColor.Grey.tone500.rgb, DSPrimitiveColor.Grey.tone600.rgb)
        XCTAssertEqual(
            DSPrimitiveColor.all.count,
            Set(DSPrimitiveColor.all.values.map(\.sourceID)).count
        )
    }

    func testEveryScaleStepMatchesTheModeOneExport() {
        XCTAssertEqual(
            [
                "scale.0": ScaleContract(0, "VariableID:16:71"),
                "scale.50": ScaleContract(2, "VariableID:16:79"),
                "scale.100": ScaleContract(4, "VariableID:16:68"),
                "scale.200": ScaleContract(8, "VariableID:16:69"),
                "scale.300": ScaleContract(12, "VariableID:16:70"),
                "scale.400": ScaleContract(16, "VariableID:16:72"),
                "scale.500": ScaleContract(20, "VariableID:16:73"),
                "scale.600": ScaleContract(24, "VariableID:16:74"),
                "scale.700": ScaleContract(28, "VariableID:16:75"),
                "scale.800": ScaleContract(32, "VariableID:16:76"),
                "scale.900": ScaleContract(36, "VariableID:16:77"),
                "scale.1000": ScaleContract(40, "VariableID:16:78"),
                "scale.1100": ScaleContract(44, "VariableID:16:80"),
                "scale.1200": ScaleContract(48, "VariableID:16:81"),
                "scale.1300": ScaleContract(52, "VariableID:16:82"),
                "scale.1400": ScaleContract(56, "VariableID:16:83"),
                "scale.1500": ScaleContract(60, "VariableID:16:84"),
                "scale.1600": ScaleContract(64, "VariableID:16:85"),
            ],
            DSPrimitiveScale.all.mapValues { token in
                ScaleContract(token.value, token.sourceID)
            }
        )
        XCTAssertEqual(
            DSPrimitiveScale.all.count,
            Set(DSPrimitiveScale.all.values.map(\.sourceID)).count
        )
    }

    func testEveryTypographyPrimitiveMatchesTheModeOneExport() {
        XCTAssertEqual(
            [
                "Sharp Grotesk SmBold 20": "VariableID:16:63",
                "SF Pro Display": "VariableID:16:64",
            ],
            Dictionary(
                uniqueKeysWithValues: DSPrimitiveTypography.FontFamily.allCases.map { family in
                    (family.sourceName, family.sourceID)
                }
            )
        )
        XCTAssertEqual(
            [
                "Light": "VariableID:2009:282",
                "Regular": "VariableID:16:65",
                "Medium": "VariableID:16:66",
                "Semibold": "VariableID:16:86",
                "Bold": "VariableID:16:67",
            ],
            Dictionary(
                uniqueKeysWithValues: DSPrimitiveTypography.FontWeight.allCases.map { weight in
                    (weight.sourceName, weight.sourceID)
                }
            )
        )
    }

    func testPlatformExtensionsRemainExplicit() {
        XCTAssertEqual(DSPlatformTokenExtension.bodyTypeface, .nativeSystem)
        XCTAssertEqual(
            DSPlatformTokenExtension.designPendingDomains,
            Set([
                .typographyMetrics,
                .radius,
                .border,
                .shadow,
                .componentMetrics
            ])
        )
    }

    private struct ColorContract: Equatable {
        let rgb: UInt32
        let opacity: Double
        let sourceID: String

        init(_ rgb: UInt32, _ opacity: Double, _ sourceID: String) {
            self.rgb = rgb
            self.opacity = opacity
            self.sourceID = sourceID
        }
    }

    private struct ScaleContract: Equatable {
        let value: CGFloat
        let sourceID: String

        init(_ value: CGFloat, _ sourceID: String) {
            self.value = value
            self.sourceID = sourceID
        }
    }
}
