import XCTest
@testable import FeatureStart

final class StartVersionCaptionTests: XCTestCase {
    func testFormatsMarketingVersionAndBuild() {
        XCTAssertEqual(
            StartVersionCaption.text(
                version: " 0.2 ",
                build: " 9 ",
                withBuildFormat: "Version %1$@ (%2$@)",
                versionOnlyFormat: "Version %1$@"
            ),
            "Version 0.2 (9)"
        )
    }

    func testFallsBackToVersionOnlyWhenBuildIsMissing() {
        for build in ["", " ", "\n"] {
            XCTAssertEqual(
                StartVersionCaption.text(
                    version: "0.2",
                    build: build,
                    withBuildFormat: "Version %1$@ (%2$@)",
                    versionOnlyFormat: "Version %1$@"
                ),
                "Version 0.2",
                "build \(build.debugDescription)"
            )
        }
    }

    func testHidesCaptionWhenMarketingVersionIsMissing() {
        for version in ["", " "] {
            XCTAssertNil(
                StartVersionCaption.text(
                    version: version,
                    build: "9",
                    withBuildFormat: "Version %1$@ (%2$@)",
                    versionOnlyFormat: "Version %1$@"
                ),
                "version \(version.debugDescription)"
            )
        }
    }

    func testCatalogFormatsEveryLanguage() {
        let expectedWithBuild = [
            "en": "Version 0.2 (9)",
            "sk": "Verzia 0.2 (9)",
            "hu": "Verzió 0.2 (9)",
        ]
        let expectedVersionOnly = [
            "en": "Version 0.2",
            "sk": "Verzia 0.2",
            "hu": "Verzió 0.2",
        ]
        for language in expectedWithBuild.keys {
            let locale = Locale(identifier: language)
            let withBuild = StartLocalizedString.string("start.version.caption", locale: locale)
            let versionOnly = StartLocalizedString.string("start.version.caption.versionOnly", locale: locale)
            XCTAssertEqual(
                StartVersionCaption.text(
                    version: "0.2",
                    build: "9",
                    withBuildFormat: withBuild,
                    versionOnlyFormat: versionOnly
                ),
                expectedWithBuild[language],
                language
            )
            XCTAssertEqual(
                StartVersionCaption.text(
                    version: "0.2",
                    build: "",
                    withBuildFormat: withBuild,
                    versionOnlyFormat: versionOnly
                ),
                expectedVersionOnly[language],
                language
            )
        }
    }
}
