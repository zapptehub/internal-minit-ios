import SwiftUI
import UIKit
import XCTest
import DesignSystem
@testable import FeatureOnboarding

/// Card centre against the live headline and Continue frames.
/// Centering on the step (the previous overlay) does not satisfy
/// `(headlineBottom + buttonTop - 56) / 2`.
@MainActor
final class CreateCardStatusLayoutTests: XCTestCase {
    func testMetricsLiftTheCardByHalfTheSlotPaddingAndBottomInset() {
        XCTAssertEqual(CreateCardStatusMetrics.centeringBottomInset, 56)
        XCTAssertEqual(DSConstant.large.value, 24)
        XCTAssertEqual(CreateCardStatusMetrics.contentCenterLift, 40)
    }

    func testCardCentreFollowsTheFigmaSlot() {
        let box = FrameBox()
        let host = UIHostingController(
            rootView: CreateCardLayoutHarness(
                viewModel: PreviewOnboarding.makeViewModel(),
                box: box
            )
            .environment(\.dynamicTypeSize, .large)
        )
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds

        let deadline = Date().addingTimeInterval(2)
        while box.frames.count < 3, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        let header = box.frames[OnboardingFrameID.header]
        let bar = box.frames[OnboardingFrameID.bottomBar]
        let card = box.frames[OnboardingFrameID.statusCard]
        XCTAssertNotNil(header, "missing header frame \(box.frames)")
        XCTAssertNotNil(bar, "missing button frame \(box.frames)")
        XCTAssertNotNil(card, "missing card frame \(box.frames)")
        guard let header, let bar, let card else { return }

        let expected = (header.maxY + bar.minY - CreateCardStatusMetrics.centeringBottomInset) / 2
        print(
            "CREATECARD_FIGMA ios position card=\(card) headerBottom=\(header.maxY) " +
            "buttonTop=\(bar.minY) center=\(card.midY) expected=\(expected) " +
            "stepCenter=\(window.bounds.midY)"
        )

        XCTAssertEqual(card.width, 354, accuracy: 1, "card width \(card.width)")
        XCTAssertEqual(bar.height, 56, accuracy: 2, "button height \(bar.height)")
        XCTAssertEqual(card.midY, expected, accuracy: 2, "center \(card.midY) expected \(expected)")
        XCTAssertLessThan(card.maxY, bar.minY, "card overlaps Continue")
    }

    func testCreateCardPrimaryTitleIsContinueNotEnterMinit() throws {
        let primaryLine = try XCTUnwrap(
            createCardScreenSource()
                .split(whereSeparator: \.isNewline)
                .first { $0.contains("primaryTitle:") }
        )
        XCTAssertTrue(
            primaryLine.contains("\"onboarding.button.continue\""),
            String(primaryLine)
        )
        XCTAssertFalse(primaryLine.contains("enterMinit"), String(primaryLine))

        let cases: [(locale: String, title: String, retired: String)] = [
            ("en", "Continue", "Enter Minit"),
            ("sk", "Pokračovať", "Vstúpiť do Minit"),
            ("hu", "Folytatás", "Belépés a Minitbe"),
        ]
        for item in cases {
            let locale = Locale(identifier: item.locale)
            let resolved = OnboardingLocalizedString.string("onboarding.button.continue", locale: locale)
            let retired = OnboardingLocalizedString.string("onboarding.button.enterMinit", locale: locale)
            XCTAssertEqual(resolved, item.title, item.locale)
            XCTAssertEqual(retired, item.retired, item.locale)
            XCTAssertNotEqual(resolved, retired, item.locale)
        }
    }
}

private func createCardScreenSource() throws -> String {
    let screen = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/FeatureOnboarding/UI/Views/CreateCardScreen.swift")
    return try String(contentsOf: screen, encoding: .utf8)
}

private final class FrameBox {
    var frames: [Int: CGRect] = [:]
}

private struct CreateCardLayoutHarness: View {
    @State var viewModel: OnboardingViewModel
    let box: FrameBox

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(progress: 0.85)
                .padding(.top, DSConstant.medium.value)
                .padding(.horizontal, DSConstant.large.value)
            CreateCardScreen(
                viewModel: viewModel,
                analytics: PreviewOnboardingAnalyticsTracking()
            )
        }
        .frame(width: 402, height: 874)
        .coordinateSpace(name: OnboardingFrameSpace.createCard)
        .onPreferenceChange(OnboardingFramePreferenceKey.self) { box.frames = $0 }
    }
}
