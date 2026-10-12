import XCTest
import SwiftUI
import UIKit
@testable import DesignSystem

@MainActor
final class DesignSystemAccessibilityTests: XCTestCase {
    func testAccessibilityStringsMatchAndroid() {
        let cases: [(String, String, String, String)] = [
            ("common.a11y.showPassword", "Show password", "Jelszó megjelenítése", "Zobraziť heslo"),
            ("common.a11y.hidePassword", "Hide password", "Jelszó elrejtése", "Skryť heslo"),
            ("common.a11y.openCalendar", "Open calendar", "Naptár megnyitása", "Otvoriť kalendár"),
            ("common.a11y.loading", "Loading", "Betöltés", "Načítava sa"),
            ("common.a11y.inputError", "Invalid input", "Érvénytelen bevitel", "Neplatný vstup"),
            ("common.a11y.inputValid", "Valid input", "Érvényes bevitel", "Platný vstup"),
            ("common.a11y.selectionError", "Invalid selection", "Érvénytelen választás", "Neplatný výber"),
            ("common.a11y.bannerPosition", "Banner %1$d of %2$d", "%1$d. banner, összesen %2$d", "Banner %1$d z %2$d"),
            ("common.a11y.challengeProgress", "%1$d of %2$d completed", "%1$d / %2$d teljesítve", "%1$d z %2$d splnené"),
        ]
        for (key, en, hu, sk) in cases {
            XCTAssertEqual(DesignSystemA11y.text(key, locale: Locale(identifier: "en")), en, key)
            XCTAssertEqual(DesignSystemA11y.text(key, locale: Locale(identifier: "hu")), hu, key)
            XCTAssertEqual(DesignSystemA11y.text(key, locale: Locale(identifier: "sk")), sk, key)
        }
        XCTAssertEqual(
            DesignSystemA11y.format("common.a11y.bannerPosition", locale: Locale(identifier: "hu"), 2, 5),
            "2. banner, összesen 5"
        )
        XCTAssertEqual(
            DesignSystemA11y.format("common.a11y.challengeProgress", locale: Locale(identifier: "sk"), 1, 4),
            "1 z 4 splnené"
        )
    }

    func testPasswordCalendarAndValidationLabelsFollowTheLocale() {
        let hungarian = Locale(identifier: "hu")
        let password = AccessibilitySnapshot(
            DSInputField(label: "Jelszó", text: .constant("secret"), type: .password)
                .environment(\.locale, hungarian)
        )
        XCTAssertTrue(
            password.contains(label: "Jelszó megjelenítése"),
            password.debugDescription
        )

        let calendar = AccessibilitySnapshot(
            DSInputField(
                label: "Dátum",
                text: .constant(""),
                type: .date,
                onCalendarTap: {}
            )
            .environment(\.locale, Locale(identifier: "sk"))
        )
        XCTAssertTrue(
            calendar.contains(label: "Otvoriť kalendár"),
            calendar.debugDescription
        )

        let invalid = AccessibilitySnapshot(
            DSInputField(
                label: "Email",
                text: .constant(""),
                validationState: .error
            )
            .environment(\.locale, hungarian)
        )
        XCTAssertTrue(
            invalid.contains(hint: "Érvénytelen bevitel"),
            invalid.debugDescription
        )

        let valid = AccessibilitySnapshot(
            DSInputField(
                label: "Név",
                text: .constant("Iveta"),
                validationState: .success
            )
            .environment(\.locale, hungarian)
        )
        XCTAssertTrue(
            valid.contains(hint: "Érvényes bevitel"),
            valid.debugDescription
        )
    }

    func testLoadingSelectionBannerAndChallengeLabelsFollowTheLocale() {
        let slovak = Locale(identifier: "sk")
        let button = AccessibilitySnapshot(
            DSButton(title: "Pokračovať", type: .primary, isLoading: true) {}
                .environment(\.locale, slovak)
        )
        XCTAssertTrue(button.contains(label: "Pokračovať"), button.debugDescription)
        XCTAssertTrue(button.contains(value: "Načítava sa"), button.debugDescription)

        let card = AccessibilitySnapshot(
            DSStatusCard(state: .loading(title: "Mentés", subtitle: "Egy pillanat"))
                .environment(\.locale, Locale(identifier: "hu"))
        )
        XCTAssertTrue(card.contains(value: "Betöltés"), card.debugDescription)

        let checkbox = AccessibilitySnapshot(
            DSCheckbox(label: "Hírlevél", isChecked: .constant(false), hasError: true)
                .environment(\.locale, Locale(identifier: "hu"))
        )
        XCTAssertTrue(
            checkbox.contains(hint: "Érvénytelen választás"),
            checkbox.debugDescription
        )

        let radios = AccessibilitySnapshot(
            DSRadioGroup(
                options: [.init(value: 1, label: "Egy")],
                selection: .constant(1),
                hasError: true
            )
            .environment(\.locale, Locale(identifier: "hu"))
        )
        XCTAssertTrue(
            radios.contains(hint: "Érvénytelen választás"),
            radios.debugDescription
        )

        let banners = AccessibilitySnapshot(
            DSBannerCarousel(
                items: [
                    .init(id: 0, backgroundColor: .brown, title: Text("Első")),
                    .init(id: 1, backgroundColor: .orange, title: Text("Második")),
                ],
                onBannerTap: {}
            )
            .frame(width: 390, height: 120)
            .environment(\.locale, Locale(identifier: "hu"))
        )
        XCTAssertTrue(banners.contains(value: "1. banner, összesen 2"), banners.debugDescription)

        let challenges = AccessibilitySnapshot(
            DSChallengesCardRow(
                items: [
                    DSChallengesCardList.Item(
                        id: 0,
                        backgroundColor: .brown,
                        icon: .croissant,
                        badgeText: "+10",
                        title: "Pizza",
                        repeatCount: 4,
                        progress: 1
                    ),
                ]
            )
            .frame(width: 390, height: 160)
            .environment(\.locale, Locale(identifier: "en"))
        )
        XCTAssertTrue(
            challenges.contains(label: "Pizza, +10"),
            challenges.debugDescription
        )
        XCTAssertTrue(
            challenges.contains(value: "1 of 4 completed"),
            challenges.debugDescription
        )
    }

    func testChallengeCardLabelIncludesBadgeAndProgressIsTheValue() throws {
        let english = VoiceOverSnapshot(
            DSChallengesCardRow(
                items: [
                    DSChallengesCardList.Item(
                        id: 0,
                        backgroundColor: .orange,
                        icon: .qrScanLine,
                        badgeText: "+45 pts",
                        title: "Use the Minit loyalty card 4 times",
                        repeatCount: 4,
                        progress: 0
                    ),
                ]
            )
            .frame(width: 390, height: 160)
            .environment(\.locale, Locale(identifier: "en"))
        )
        let cards = english.nodes.filter { $0.traits.contains(.button) }
        XCTAssertEqual(cards.count, 1, english.debugDescription)
        let card = try XCTUnwrap(cards.first)
        XCTAssertEqual(card.label, "Use the Minit loyalty card 4 times, +45 pts")
        XCTAssertEqual(card.value, "0 of 4 completed")
        XCTAssertFalse(english.contains(label: "Use the Minit loyalty card 4 times"), english.debugDescription)
        XCTAssertFalse(english.contains(label: "+45 pts"), english.debugDescription)

        let hungarian = VoiceOverSnapshot(
            DSChallengesCardRow(
                items: [
                    DSChallengesCardList.Item(
                        id: 0,
                        backgroundColor: .orange,
                        icon: .qrScanLine,
                        badgeText: "+45 pts",
                        title: "Hűségkártya",
                        repeatCount: 4,
                        progress: 0
                    ),
                ]
            )
            .frame(width: 390, height: 160)
            .environment(\.locale, Locale(identifier: "hu"))
        )
        let hungarianCards = hungarian.nodes.filter { $0.label == "Hűségkártya, +45 pts" }
        XCTAssertEqual(hungarianCards.count, 1, hungarian.debugDescription)
        XCTAssertEqual(hungarianCards[0].value, "0 / 4 teljesítve")
    }

    func testCurrentBannerIsOneButtonWithFullTextAndPosition() throws {
        let title = Text("Buy ").foregroundColor(.white)
            + Text("1").foregroundColor(.orange)
            + Text(" get ").foregroundColor(.white)
            + Text("2").foregroundColor(.orange)
            + Text(" Croissants").foregroundColor(.white)
        let snapshot = VoiceOverSnapshot(
            DSBannerCarousel(
                items: [
                    .init(id: 0, backgroundColor: .pink, badgeText: "Morning", title: Text("First offer")),
                    .init(
                        id: 1,
                        backgroundColor: .brown,
                        badgeText: "Daily Offer",
                        title: title
                    ),
                    .init(id: 2, backgroundColor: .green, badgeText: "Evening", title: Text("Third offer")),
                ],
                initialIndex: 1,
                onBannerTap: {}
            )
            .frame(width: 390, height: 120)
            .environment(\.locale, Locale(identifier: "en"))
        )

        let banners = snapshot.nodes.filter { $0.value?.hasPrefix("Banner ") == true }
        XCTAssertEqual(banners.count, 1, snapshot.debugDescription)
        let banner = try XCTUnwrap(banners.first)
        XCTAssertEqual(banner.label, "Daily Offer, Buy 1 get 2 Croissants")
        XCTAssertEqual(banner.value, "Banner 2 of 3")
        XCTAssertTrue(banner.traits.contains(.button), snapshot.debugDescription)
        XCTAssertTrue(banner.traits.contains(.adjustable), snapshot.debugDescription)
        XCTAssertGreaterThanOrEqual(banner.frame.height, 44, snapshot.debugDescription)
        XCTAssertGreaterThanOrEqual(banner.frame.width, 120, snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "Daily Offer"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "Buy 1 get 2 Croissants"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "Morning"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "First offer"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "Evening"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "Third offer"), snapshot.debugDescription)
    }

    func testCallerAccessibilityLabelReplacesTheVisibleBannerText() throws {
        let snapshot = VoiceOverSnapshot(
            DSBannerCarousel(
                items: [
                    .init(
                        id: 3,
                        backgroundColor: .brown,
                        badgeText: "Daily Offer",
                        title: Text("15%").foregroundColor(.orange)
                            + Text(" Off on every coffee").foregroundColor(.white)
                    ),
                ],
                onBannerTap: {},
                accessibilityLabel: "Daily Offer"
            )
            .frame(width: 390, height: 120)
            .environment(\.locale, Locale(identifier: "en"))
        )

        let banners = snapshot.nodes.filter { $0.label == "Daily Offer" }
        XCTAssertEqual(banners.count, 1, snapshot.debugDescription)
        let banner = try XCTUnwrap(banners.first)
        XCTAssertTrue(banner.traits.contains(.button), snapshot.debugDescription)
        XCTAssertTrue(banner.traits.contains(.adjustable), snapshot.debugDescription)
        XCTAssertEqual(banner.value, "Banner 1 of 1")
        XCTAssertFalse(
            snapshot.nodes.contains { $0.label?.contains("15%") == true },
            snapshot.debugDescription
        )
        XCTAssertFalse(
            snapshot.nodes.contains { $0.label?.contains("Off on every coffee") == true },
            snapshot.debugDescription
        )
    }

    func testBannerCarouselIsAdjustableAndClampsAtTheEnds() throws {
        try assertBannerCarouselAdjusts(reduceMotion: false)
    }

    func testBannerCarouselAdjustsWhenReduceMotionSnapsTheScroll() throws {
        try assertBannerCarouselAdjusts(reduceMotion: true)
    }

    func testSingleBannerCarouselAdjustStaysPutAndStillOpens() throws {
        let taps = TapCounter()
        let host = BannerAccessibilityHarness(
            DSBannerCarousel(
                items: [
                    .init(
                        id: 3,
                        backgroundColor: .brown,
                        badgeText: "Daily Offer",
                        title: Text("Coffee")
                    ),
                ],
                onBannerTap: { taps.count += 1 },
                accessibilityLabel: "Daily Offer"
            )
            .frame(width: 390, height: 160)
            .environment(\.locale, Locale(identifier: "en"))
        )
        defer { host.close() }

        let banner = try XCTUnwrap(
            host.waitForBanner(label: "Daily Offer", value: "Banner 1 of 1"),
            host.debugDescription
        )
        XCTAssertTrue(banner.accessibilityTraits.contains(.button), host.debugDescription)
        XCTAssertTrue(banner.accessibilityTraits.contains(.adjustable), host.debugDescription)
        XCTAssertEqual(host.bannerCount(), 1, host.debugDescription)
        let offset = try XCTUnwrap(host.contentOffsetX(), host.debugDescription)

        host.adjust(.increment)
        host.assertUnchanged(label: "Daily Offer", value: "Banner 1 of 1", offset: offset)
        host.adjust(.decrement)
        host.assertUnchanged(label: "Daily Offer", value: "Banner 1 of 1", offset: offset)

        XCTAssertTrue(host.activateCurrentBanner(), host.debugDescription)
        XCTAssertEqual(taps.count, 1)
        XCTAssertEqual(host.bannerLabel(), "Daily Offer")
        XCTAssertEqual(host.bannerValue(), "Banner 1 of 1")
    }

    /// Swipe up/down changes the current banner, its label, and its "Banner X of Y"
    /// value, and stops on the first and last pages. The scroll offset is the visible
    /// page `scrolledItemID` drives (the indicator reads that same id).
    private func assertBannerCarouselAdjusts(reduceMotion: Bool) throws {
        let taps = TapCounter()
        let host = BannerAccessibilityHarness(
            DSBannerCarousel(
                items: [
                    .init(id: 10, backgroundColor: .pink, badgeText: "Morning", title: Text("First")),
                    .init(id: 11, backgroundColor: .brown, badgeText: "Noon", title: Text("Second")),
                    .init(id: 12, backgroundColor: .green, badgeText: "Evening", title: Text("Third")),
                ],
                initialIndex: 1,
                onBannerTap: { taps.count += 1 }
            )
            .frame(width: 390, height: 160)
            .environment(\.locale, Locale(identifier: "en"))
            // The public key is read-only. This override is what the carousel reads.
            .environment(\._accessibilityReduceMotion, reduceMotion)
        )
        defer { host.close() }

        let banner = try XCTUnwrap(
            host.waitForBanner(label: "Noon, Second", value: "Banner 2 of 3"),
            host.debugDescription
        )
        XCTAssertTrue(banner.accessibilityTraits.contains(.adjustable), host.debugDescription)
        XCTAssertTrue(banner.accessibilityTraits.contains(.button), host.debugDescription)
        XCTAssertEqual(host.bannerCount(), 1, host.debugDescription)
        XCTAssertTrue(host.activateCurrentBanner(), host.debugDescription)
        XCTAssertEqual(taps.count, 1)

        // Reduce Motion snaps `scrolledItemID` into the scroll view, so the offset
        // is the visible page. With motion on, that same change animates and this
        // run loop does not commit the interpolated offset; the label still tracks it.
        let middleOffset = reduceMotion
            ? try XCTUnwrap(
                host.waitForStableOffset(where: { $0 > 40 }),
                "second page should be the visible one\n\(host.debugDescription)"
            )
            : nil

        host.adjust(.decrement)
        try host.requireBanner(label: "Morning, First", value: "Banner 1 of 3")
        let firstOffset: CGFloat?
        if let middleOffset {
            firstOffset = try XCTUnwrap(
                host.waitForStableOffset(where: { $0 < middleOffset - 40 }),
                host.debugDescription
            )
        } else {
            firstOffset = nil
        }
        host.adjust(.decrement)
        host.assertUnchanged(label: "Morning, First", value: "Banner 1 of 3", offset: firstOffset)

        host.adjust(.increment)
        try host.requireBanner(label: "Noon, Second", value: "Banner 2 of 3")
        if let middleOffset {
            _ = try XCTUnwrap(
                host.waitForStableOffset(where: { abs($0 - middleOffset) < 30 }),
                host.debugDescription
            )
        }

        host.adjust(.increment)
        try host.requireBanner(label: "Evening, Third", value: "Banner 3 of 3")
        let lastOffset: CGFloat?
        if let middleOffset {
            lastOffset = try XCTUnwrap(
                host.waitForStableOffset(where: { $0 > middleOffset + 40 }),
                host.debugDescription
            )
        } else {
            lastOffset = nil
        }
        host.adjust(.increment)
        host.assertUnchanged(label: "Evening, Third", value: "Banner 3 of 3", offset: lastOffset)

        XCTAssertEqual(host.bannerCount(), 1, host.debugDescription)
        XCTAssertTrue(host.activateCurrentBanner(), host.debugDescription)
        XCTAssertEqual(taps.count, 2)
        XCTAssertEqual(host.bannerLabel(), "Evening, Third", host.debugDescription)
        XCTAssertEqual(host.bannerValue(), "Banner 3 of 3", host.debugDescription)
    }

    func testLoyaltyCardSummaryIsAButtonAndChipIsReachable() throws {
        let taps = TapCounter()
        let card = LoyaltyCard(
            rankTitle: "Silver",
            rankSubtitle: "540 pts until Platinum",
            points: 3210,
            chipLabel: "Minit Card",
            onChipTap: { taps.count += 1 }
        )
        .frame(width: 362)
        .environment(\.locale, Locale(identifier: "en"))

        let snapshot = VoiceOverSnapshot(card)
        let buttons = snapshot.nodes.filter { $0.traits.contains(.button) }
        XCTAssertEqual(buttons.count, 2, snapshot.debugDescription)

        let summaryLabel = "Silver, 540 pts until Platinum, 3,210 points"
        let summaries = buttons.filter { $0.label == summaryLabel }
        XCTAssertEqual(summaries.count, 1, snapshot.debugDescription)
        let summary = try XCTUnwrap(summaries.first)
        XCTAssertTrue(summary.traits.contains(.button), snapshot.debugDescription)

        let chips = buttons.filter { $0.label == "Minit Card" }
        XCTAssertEqual(chips.count, 1, snapshot.debugDescription)
        let chip = try XCTUnwrap(chips.first)
        XCTAssertTrue(chip.traits.contains(.button), snapshot.debugDescription)
        XCTAssertGreaterThan(chip.frame.minY, summary.frame.minY, snapshot.debugDescription)

        XCTAssertFalse(snapshot.contains(label: "Silver"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "540 pts until Platinum"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "3,210"), snapshot.debugDescription)

        XCTAssertTrue(activateAccessibility(label: summaryLabel, in: card))
        XCTAssertEqual(taps.count, 1)
        XCTAssertTrue(activateAccessibility(label: "Minit Card", in: card))
        XCTAssertEqual(taps.count, 2)
    }

    func testLoyaltyCardSummaryButtonTraitAndActionFollowChipTap() throws {
        let summaryLabel = "Silver, 540 pts until Platinum, 3,210 points"
        let taps = TapCounter()
        let interactive = loyaltyCardAccessibilityView(onChipTap: { taps.count += 1 })
        let interactiveSnapshot = VoiceOverSnapshot(interactive, until: loyaltyCardSummaryReady(summaryLabel))
        let summaries = interactiveSnapshot.nodes.filter { $0.label == summaryLabel }
        XCTAssertEqual(summaries.count, 1, interactiveSnapshot.debugDescription)
        XCTAssertTrue(summaries[0].traits.contains(.button), interactiveSnapshot.debugDescription)
        let chips = interactiveSnapshot.nodes.filter { $0.label == "Minit Card" }
        XCTAssertEqual(chips.count, 1, interactiveSnapshot.debugDescription)
        XCTAssertTrue(chips[0].traits.contains(.button), interactiveSnapshot.debugDescription)
        XCTAssertEqual(accessibilityActivation(label: summaryLabel, in: interactive), true)
        XCTAssertEqual(taps.count, 1)

        let preview = loyaltyCardAccessibilityView(onChipTap: nil)
        let previewSnapshot = VoiceOverSnapshot(preview, until: loyaltyCardSummaryReady(summaryLabel))
        let previewSummaries = previewSnapshot.nodes.filter { $0.label == summaryLabel }
        XCTAssertEqual(previewSummaries.count, 1, previewSnapshot.debugDescription)
        XCTAssertFalse(previewSummaries[0].traits.contains(.button), previewSnapshot.debugDescription)
        let previewChips = previewSnapshot.nodes.filter { $0.label == "Minit Card" }
        XCTAssertEqual(previewChips.count, 1, previewSnapshot.debugDescription)
        XCTAssertTrue(previewChips[0].traits.contains(.button), previewSnapshot.debugDescription)
        XCTAssertEqual(accessibilityActivation(label: summaryLabel, in: preview), false)
    }

    func testHostedLoyaltyPopupIsModalWithHeadingAndQrLabel() throws {
        let cases: [(String, String, String)] = [
            ("en", "My loyalty card", "Loyalty card QR code"),
            ("hu", "Hűségkártyám", "Hűségkártya QR-kód"),
            ("sk", "Moja vernostná karta", "QR kód vernostnej karty"),
        ]
        for (identifier, title, qr) in cases {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(
                DesignSystemA11y.text("common.a11y.loyaltyCardQrCode", locale: locale),
                qr,
                identifier
            )
            let snapshot = VoiceOverSnapshot(
                LoyaltyPopupAccessibilityHarness(isPresented: true)
                    .environment(\.locale, locale),
                settle: 1
            )
            XCTAssertTrue(snapshot.hasModalView, snapshot.debugDescription)
            XCTAssertFalse(snapshot.contains(label: "Home behind"), "\(identifier)\n\(snapshot.debugDescription)")
            XCTAssertFalse(snapshot.contains(label: "Home"), "\(identifier)\n\(snapshot.debugDescription)")
            XCTAssertFalse(snapshot.contains(label: "Offers"), "\(identifier)\n\(snapshot.debugDescription)")
            XCTAssertFalse(snapshot.contains(label: "Offers behind"), "\(identifier)\n\(snapshot.debugDescription)")
            XCTAssertFalse(
                snapshot.nodes.contains { node in
                    [node.label, node.value, node.identifier].contains { text in
                        text?.localizedCaseInsensitiveContains("mockQrCode") == true
                    }
                },
                snapshot.debugDescription
            )

            let titles = snapshot.nodes.filter { $0.label == title }
            XCTAssertEqual(titles.count, 1, snapshot.debugDescription)
            let titleNode = try XCTUnwrap(titles.first)
            XCTAssertTrue(titleNode.traits.contains(.header), snapshot.debugDescription)
            XCTAssertTrue(titleNode.insideModal, snapshot.debugDescription)

            let codes = snapshot.nodes.filter { $0.label == qr }
            XCTAssertEqual(codes.count, 1, snapshot.debugDescription)
            let code = try XCTUnwrap(codes.first)
            XCTAssertTrue(code.traits.contains(.image), snapshot.debugDescription)
            XCTAssertTrue(code.insideModal, snapshot.debugDescription)
            XCTAssertFalse(code.traits.contains(.header), snapshot.debugDescription)
        }
    }

    func testClosedLoyaltyPopupLeavesTheScreenBehindReachable() {
        let snapshot = VoiceOverSnapshot(
            LoyaltyPopupPlainHarness()
                .environment(\.locale, Locale(identifier: "en"))
        )
        XCTAssertTrue(snapshot.contains(label: "Home behind"), snapshot.debugDescription)
        XCTAssertTrue(snapshot.contains(label: "Offers"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.hasModalView, snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "My loyalty card"), snapshot.debugDescription)
        XCTAssertFalse(snapshot.contains(label: "Loyalty card QR code"), snapshot.debugDescription)
    }

    func testCollectionHeaderTitleIsAHeaderAndSeeAllIsNot() {
        let snapshot = VoiceOverSnapshot(
            DSCollectionHeader(title: "Products", onSeeAllTapped: {})
                .frame(width: 402)
                .environment(\.locale, Locale(identifier: "en"))
        )
        let titles = snapshot.nodes.filter { $0.label == "Products" }
        XCTAssertEqual(titles.count, 1, snapshot.debugDescription)
        XCTAssertTrue(titles[0].traits.contains(.header), snapshot.debugDescription)

        let seeAll = snapshot.nodes.filter { $0.label == "See all" }
        XCTAssertEqual(seeAll.count, 1, snapshot.debugDescription)
        XCTAssertFalse(seeAll[0].traits.contains(.header), snapshot.debugDescription)
    }

    func testUnderConstructionHeadlineIsAHeaderAndTheMessageIsNot() {
        let snapshot = VoiceOverSnapshot(
            UnderConstructionScreen(headlineKey: "common.tabName.offers")
                .environment(\.locale, Locale(identifier: "en"))
        )
        let headlines = snapshot.nodes.filter { $0.label == "Offers" }
        XCTAssertEqual(headlines.count, 1, snapshot.debugDescription)
        XCTAssertTrue(headlines[0].traits.contains(.header), snapshot.debugDescription)

        let messages = snapshot.nodes.filter {
            $0.label == "This screen is under construction. Check back soon!"
        }
        XCTAssertEqual(messages.count, 1, snapshot.debugDescription)
        XCTAssertFalse(messages[0].traits.contains(.header), snapshot.debugDescription)
    }

    func testWarningMessageIsOneElementAndAnnouncesPolitelyWhenItAppears() {
        let log = AnnouncementLog()
        let message = "Please enter a valid email address."
        let snapshot = VoiceOverSnapshot(
            DSWarningMessage(message: message)
                .environment(\.dsPoliteAnnouncement, DSPoliteAnnouncementAction { log.messages.append($0) })
        )
        XCTAssertEqual(snapshot.nodes.map(\.label), [message], snapshot.debugDescription)
        XCTAssertFalse(
            snapshot.nodes.contains { node in
                let label = (node.label ?? "").lowercased()
                return label.contains("exclamation") || label.contains("triangle") || label == "warning"
            },
            snapshot.debugDescription
        )
        XCTAssertEqual(log.messages, [message])

        let polite = DSPoliteAnnouncement.attributed(message)
        XCTAssertEqual(polite.map { String($0.characters) }, message)
        XCTAssertEqual(polite?.accessibilitySpeechAnnouncementPriority, .low)
        XCTAssertNil(DSPoliteAnnouncement.attributed(""))
        XCTAssertNil(DSPoliteAnnouncement.attributed("   "))
    }

    func testWarningMessageAnnouncesAgainWhenTheMessageChanges() {
        let log = AnnouncementLog()
        let box = WarningMessageBox(message: "First warning")
        let host = UIHostingController(
            rootView: WarningMessageHarness(box: box)
                .environment(\.dsPoliteAnnouncement, DSPoliteAnnouncementAction { log.messages.append($0) })
        )
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(log.messages, ["First warning"])

        box.message = "Second warning"
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(log.messages, ["First warning", "Second warning"])
        window.isHidden = true
    }
}

private final class AnnouncementLog {
    var messages: [String] = []
}

private final class WarningMessageBox: ObservableObject {
    @Published var message: String

    init(message: String) {
        self.message = message
    }
}

private struct WarningMessageHarness: View {
    @ObservedObject var box: WarningMessageBox

    var body: some View {
        DSWarningMessage(message: box.message)
    }
}

/// Home stand-in under `.dsPopupHost()`, the same placement as the loyalty popup on the tab root.
private struct LoyaltyPopupAccessibilityHarness: View {
    let isPresented: Bool

    var body: some View {
        TabView {
            VStack(spacing: 0) {
                Text("Home behind")
                Spacer(minLength: 0)
            }
            .dsPopup(isPresented: .constant(isPresented)) {
                LoyaltyCardDetailView(onClose: {})
            }
            .tabItem { Text("Home") }

            Text("Offers behind")
                .tabItem { Text("Offers") }
        }
        .dsPopupHost()
    }
}

/// Same popup without a tab bar, so the closed tree still exposes the screen behind it.
private struct LoyaltyPopupPlainHarness: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Home behind")
            Button("Offers") {}
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dsPopup(isPresented: .constant(false)) {
            LoyaltyCardDetailView(onClose: {})
        }
        .dsPopupHost()
    }
}

@MainActor
private struct AccessibilitySnapshot {
    let nodes: [AccessibilityNode]

    init(_ view: some View) {
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        var collected: [AccessibilityNode] = []
        var visited: Set<ObjectIdentifier> = []
        if let view = host.view {
            collectAccessibility(view, into: &collected, visited: &visited)
        }
        nodes = collected
        window.isHidden = true
    }

    func contains(label: String) -> Bool {
        nodes.contains { $0.label == label }
    }

    func contains(value: String) -> Bool {
        nodes.contains { $0.value == value }
    }

    func contains(hint: String) -> Bool {
        nodes.contains { $0.hint == hint }
    }

    var debugDescription: String {
        nodes.map { "label=\($0.label ?? "-") value=\($0.value ?? "-") hint=\($0.hint ?? "-")" }
            .joined(separator: "\n")
    }
}

private struct AccessibilityNode {
    var label: String?
    var value: String?
    var hint: String?
}

@MainActor
private func collectAccessibility(
    _ object: Any,
    into nodes: inout [AccessibilityNode],
    visited: inout Set<ObjectIdentifier>
) {
    guard let accessibility = object as? NSObject else { return }
    let identity = ObjectIdentifier(accessibility)
    guard visited.insert(identity).inserted else { return }
    let label = accessibility.accessibilityLabel
    let value = accessibility.accessibilityValue
    let hint = accessibility.accessibilityHint
    if label?.isEmpty == false || value?.isEmpty == false || hint?.isEmpty == false {
        nodes.append(AccessibilityNode(label: label, value: value, hint: hint))
    }
    if let elements = accessibility.accessibilityElements {
        for element in elements {
            collectAccessibility(element, into: &nodes, visited: &visited)
        }
    }
    if let view = object as? UIView {
        let count = view.accessibilityElementCount()
        if count != NSNotFound && count > 0 && count < 100 {
            for index in 0..<count {
                if let element = view.accessibilityElement(at: index) {
                    collectAccessibility(element, into: &nodes, visited: &visited)
                }
            }
        }
        for subview in view.subviews {
            collectAccessibility(subview, into: &nodes, visited: &visited)
        }
    }
}

@MainActor
private struct VoiceOverSnapshot {
    let nodes: [VoiceOverNode]
    let hasModalView: Bool

    init(
        _ view: some View,
        settle: TimeInterval = 0.5,
        until ready: (([VoiceOverNode]) -> Bool)? = nil,
        timeout: TimeInterval = 2
    ) {
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds

        func snapshotNodes() -> [VoiceOverNode] {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            var collected: [VoiceOverNode] = []
            var visited: Set<ObjectIdentifier> = []
            if let view = host.view {
                collectVoiceOver(view, into: &collected, visited: &visited)
            }
            return collected
        }

        let collected: [VoiceOverNode]
        if let ready {
            let deadline = Date().addingTimeInterval(timeout)
            var nodes = snapshotNodes()
            while !ready(nodes), Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
                nodes = snapshotNodes()
            }
            collected = nodes
        } else {
            RunLoop.current.run(until: Date().addingTimeInterval(settle))
            collected = snapshotNodes()
        }
        let modalFrames = host.view.map(modalViewFrames) ?? []
        nodes = collected.map { node in
            var node = node
            node.insideModal = modalFrames.contains { frame in
                frame.insetBy(dx: -1, dy: -1).contains(node.frame)
            }
            return node
        }
        hasModalView = !modalFrames.isEmpty
        window.isHidden = true
    }

    func contains(label: String) -> Bool {
        nodes.contains { $0.label == label }
    }

    var debugDescription: String {
        let body = nodes.map { node in
            "label=\(node.label ?? "-") value=\(node.value ?? "-") id=\(node.identifier ?? "-") traits=\(node.traitDescription) modal=\(node.insideModal) frame=\(node.frame)"
        }
        .joined(separator: "\n")
        return "hasModalView=\(hasModalView)\n\(body)"
    }
}

private struct VoiceOverNode {
    var label: String?
    var value: String?
    var identifier: String?
    var traits: UIAccessibilityTraits
    var insideModal: Bool
    var frame: CGRect

    var traitDescription: String {
        var names: [String] = []
        if traits.contains(.button) { names.append("button") }
        if traits.contains(.adjustable) { names.append("adjustable") }
        if traits.contains(.header) { names.append("header") }
        if traits.contains(.staticText) { names.append("staticText") }
        if traits.contains(.image) { names.append("image") }
        return names.isEmpty ? String(traits.rawValue) : names.joined(separator: ",")
    }
}

@MainActor
private func collectVoiceOver(
    _ object: Any,
    into nodes: inout [VoiceOverNode],
    visited: inout Set<ObjectIdentifier>
) {
    guard let accessibility = unwrapAccessibilityObject(object) else { return }
    let identity = ObjectIdentifier(accessibility)
    guard visited.insert(identity).inserted else { return }
    if accessibility.accessibilityElementsHidden { return }
    if let view = accessibility as? UIView, view.isHidden { return }

    if accessibility.isAccessibilityElement {
            let label = accessibility.accessibilityLabel
            let value = accessibility.accessibilityValue
            if label?.isEmpty == false || value?.isEmpty == false {
                nodes.append(
                    VoiceOverNode(
                        label: label,
                        value: value,
                        identifier: (accessibility as? UIAccessibilityIdentification)?.accessibilityIdentifier,
                        traits: accessibility.accessibilityTraits,
                        insideModal: false,
                        frame: accessibility.accessibilityFrame
                    )
                )
            }
            return
        }

    if let elements = accessibility.accessibilityElements {
        for element in elements {
            collectVoiceOver(element, into: &nodes, visited: &visited)
        }
        return
    }

    guard let view = accessibility as? UIView else { return }
    let count = view.accessibilityElementCount()
    if count != NSNotFound {
        if count > 0 && count < 200 {
            for index in 0..<count {
                if let element = view.accessibilityElement(at: index) {
                    collectVoiceOver(element, into: &nodes, visited: &visited)
                }
            }
        }
        return
    }
    for subview in view.subviews {
        collectVoiceOver(subview, into: &nodes, visited: &visited)
    }
}

@MainActor
private func modalViewFrames(_ view: UIView) -> [CGRect] {
    var frames: [CGRect] = []
    if view.accessibilityViewIsModal {
        frames.append(view.convert(view.bounds, to: nil))
    }
    for subview in view.subviews {
        frames.append(contentsOf: modalViewFrames(subview))
    }
    return frames
}

/// `accessibilityElement(at:)` can hand back a nested optional that does not
/// bridge to the underlying accessibility object.
private func unwrapAccessibilityObject(_ object: Any) -> NSObject? {
    let mirror = Mirror(reflecting: object)
    if mirror.displayStyle == .optional {
        guard let child = mirror.children.first else { return nil }
        return unwrapAccessibilityObject(child.value)
    }
    return object as? NSObject
}

private final class TapCounter {
    var count = 0
}

/// Double-tap equivalent for the first accessibility element with `label`.
@MainActor
private func activateAccessibility(label: String, in view: some View) -> Bool {
    accessibilityActivation(label: label, in: view) == true
}

/// `nil` when the element never appears. `false` when it is present and its
/// default action does not run.
@MainActor
private func accessibilityActivation(label: String, in view: some View, timeout: TimeInterval = 2) -> Bool? {
    let host = UIHostingController(rootView: view)
    host.safeAreaRegions = []
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.frame = window.bounds
    defer { window.isHidden = true }

    let deadline = Date().addingTimeInterval(timeout)
    while true {
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        var visited: Set<ObjectIdentifier> = []
        if let root = host.view,
           let element = findAccessibilityElement(
            in: root,
            matching: { $0.accessibilityLabel == label },
            visited: &visited
           ) {
            return element.accessibilityActivate()
        }
        if Date() >= deadline { return nil }
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    }
}

private func loyaltyCardAccessibilityView(onChipTap: (() -> Void)?) -> some View {
    LoyaltyCard(
        rankTitle: "Silver",
        rankSubtitle: "540 pts until Platinum",
        points: 3210,
        chipLabel: "Minit Card",
        onChipTap: onChipTap
    )
    .frame(width: 362)
    .environment(\.locale, Locale(identifier: "en"))
}

private func loyaltyCardSummaryReady(_ summaryLabel: String) -> ([VoiceOverNode]) -> Bool {
    { nodes in
        nodes.contains { $0.label == summaryLabel } && nodes.contains { $0.label == "Minit Card" }
    }
}

/// Hosts a carousel and drives VoiceOver increment/decrement against the live element.
@MainActor
private final class BannerAccessibilityHarness<Content: View> {
    enum Direction {
        case increment
        case decrement
    }

    private let window: UIWindow
    private let host: UIHostingController<Content>

    init(_ view: Content) {
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        self.host = host
        self.window = window
        layout()
    }

    func close() {
        window.isHidden = true
    }

    func layout() {
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }

    func waitForBanner(label: String, value: String, timeout: TimeInterval = 2) -> NSObject? {
        var found: NSObject?
        let matched = waitUntil(timeout: timeout) {
            layout()
            found = currentBanner()
            return found?.accessibilityLabel == label && found?.accessibilityValue == value
        }
        return matched ? found : nil
    }

    func requireBanner(label: String, value: String, timeout: TimeInterval = 2) throws {
        _ = try XCTUnwrap(
            waitForBanner(label: label, value: value, timeout: timeout),
            "expected label=\(label) value=\(value)\n\(debugDescription)"
        )
    }

    func adjust(_ direction: Direction) {
        layout()
        guard let element = currentBanner() else {
            XCTFail("missing banner\n\(debugDescription)")
            return
        }
        switch direction {
        case .increment:
            element.accessibilityIncrement()
        case .decrement:
            element.accessibilityDecrement()
        }
    }

    @discardableResult
    func activateCurrentBanner() -> Bool {
        layout()
        guard let element = currentBanner() else { return false }
        return element.accessibilityActivate()
    }

    func bannerLabel() -> String? {
        currentBanner()?.accessibilityLabel
    }

    func bannerValue() -> String? {
        currentBanner()?.accessibilityValue
    }

    func bannerCount() -> Int {
        voiceOverNodes().filter { ($0.value ?? "").hasPrefix("Banner ") }.count
    }

    func contentOffsetX() -> CGFloat? {
        guard let root = host.view else { return nil }
        return scrollViews(in: root)
            .max { $0.contentSize.width < $1.contentSize.width }?
            .contentOffset.x
    }

    /// Polls until `predicate` holds and the offset stops moving.
    func waitForStableOffset(
        timeout: TimeInterval = 2,
        where predicate: (CGFloat) -> Bool
    ) -> CGFloat? {
        let deadline = Date().addingTimeInterval(timeout)
        var last: CGFloat?
        var stablePolls = 0
        while Date() < deadline {
            layout()
            if let offset = contentOffsetX(), predicate(offset) {
                if let last, abs(offset - last) < 1 {
                    stablePolls += 1
                    if stablePolls >= 3 {
                        return offset
                    }
                } else {
                    stablePolls = 0
                }
                last = offset
            } else {
                stablePolls = 0
                last = nil
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return nil
    }

    /// Negative check: the page must not change for the whole timeout.
    /// `offset` is nil when the animated scroll offset is not observable here.
    func assertUnchanged(
        label: String,
        value: String,
        offset: CGFloat? = nil,
        timeout: TimeInterval = 0.3
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            layout()
            let labelMatches = bannerLabel() == label
            let valueMatches = bannerValue() == value
            let offsetMatches = offset.map { expected in
                contentOffsetX().map { abs($0 - expected) <= 2 } ?? false
            } ?? true
            if !labelMatches || !valueMatches || !offsetMatches {
                let expectedOffset = offset.map { String(describing: $0) } ?? "nil"
                let actualOffset = contentOffsetX().map { String(describing: $0) } ?? "nil"
                XCTFail(
                    "expected to stay label=\(label) value=\(value) offset=\(expectedOffset), got label=\(bannerLabel() ?? "nil") value=\(bannerValue() ?? "nil") offset=\(actualOffset)\n\(debugDescription)"
                )
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    var debugDescription: String {
        let banner = currentBanner()
        let traits = banner.map { String($0.accessibilityTraits.rawValue) } ?? "nil"
        let lines = voiceOverNodes().map { node in
            "label=\(node.label ?? "-") value=\(node.value ?? "-") traits=\(node.traitDescription)"
        }
        return "offset=\(contentOffsetX().map { String(describing: $0) } ?? "nil") traits=\(traits)\n"
            + lines.joined(separator: "\n")
    }

    private func waitUntil(
        timeout: TimeInterval,
        poll: TimeInterval = 0.02,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() { return true }
            if Date() >= deadline { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(poll))
        }
    }

    private func currentBanner() -> NSObject? {
        guard let root = host.view else { return nil }
        var visited: Set<ObjectIdentifier> = []
        return findAccessibilityElement(in: root, matching: { element in
            (element.accessibilityValue ?? "").hasPrefix("Banner ")
        }, visited: &visited)
    }

    private func voiceOverNodes() -> [VoiceOverNode] {
        guard let root = host.view else { return [] }
        var nodes: [VoiceOverNode] = []
        var visited: Set<ObjectIdentifier> = []
        collectVoiceOver(root, into: &nodes, visited: &visited)
        return nodes
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        if let scroll = view as? UIScrollView {
            found.append(scroll)
        }
        for subview in view.subviews {
            found.append(contentsOf: scrollViews(in: subview))
        }
        return found
    }
}

@MainActor
private func findAccessibilityElement(
    in object: Any,
    matching predicate: (NSObject) -> Bool,
    visited: inout Set<ObjectIdentifier>
) -> NSObject? {
    guard let accessibility = unwrapAccessibilityObject(object) else { return nil }
    let identity = ObjectIdentifier(accessibility)
    guard visited.insert(identity).inserted else { return nil }
    if accessibility.accessibilityElementsHidden { return nil }
    if let view = accessibility as? UIView, view.isHidden { return nil }

    if accessibility.isAccessibilityElement {
        return predicate(accessibility) ? accessibility : nil
    }

    if let elements = accessibility.accessibilityElements {
        for element in elements {
            if let found = findAccessibilityElement(in: element, matching: predicate, visited: &visited) {
                return found
            }
        }
        return nil
    }

    guard let view = accessibility as? UIView else { return nil }
    let count = view.accessibilityElementCount()
    if count != NSNotFound {
        if count > 0 && count < 200 {
            for index in 0..<count {
                if let element = view.accessibilityElement(at: index),
                   let found = findAccessibilityElement(in: element, matching: predicate, visited: &visited) {
                    return found
                }
            }
        }
        return nil
    }
    for subview in view.subviews {
        if let found = findAccessibilityElement(in: subview, matching: predicate, visited: &visited) {
            return found
        }
    }
    return nil
}
