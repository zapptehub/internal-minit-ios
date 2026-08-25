import DesignSystem
import SwiftUI

/// Notifications list opened from Home's bell. All rows and the Daily Offer banner are
/// hardcoded mocks until a real notifications feed and pressable banner land.
struct NotificationsScreen: View {
    let onBack: () -> Void

    @Environment(\.locale) private var locale

    private static let rowIconCircleSize: CGFloat = 48
    private static let rowIconSize: CGFloat = 24
    private static let coinSize: CGFloat = 16

    private let todayItems: [NotificationRowData] = [
        .init(icon: .minitIcBaguette, titleKey: "home.notifications.row.firstScan", dateKey: "home.notifications.date.june12", points: 45),
        .init(icon: .minitIcBretzel, titleKey: "home.notifications.row.newProduct", dateKey: "home.notifications.date.june11", points: 45)
    ]

    private let historyItems: [NotificationRowData] = [
        .init(icon: .minitIcBaguette, titleKey: "home.notifications.row.firstScan", dateKey: "home.notifications.date.june12", points: 45),
        .init(icon: .minitIcBretzel, titleKey: "home.notifications.row.newProduct", dateKey: "home.notifications.date.june11", points: 45),
        .init(icon: .minitIcBretzel, titleKey: "home.notifications.row.newProduct", dateKey: "home.notifications.date.june11", points: 45)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSConstant.smallMedium.value) {
                backButton
                title
                dailyOfferBanner
                    // The outer VStack's uniform `smallMedium` (6pt) spacing already
                    // applies here; this tops each up to a 16pt gap — above the banner
                    // (from the title) and below it (to the "Today" section) — without
                    // touching any other gap.
                    .padding(.vertical, 16 - DSConstant.smallMedium.value)
                section(title: HomeLocalizedString.string("home.notifications.section.today", locale: locale), items: todayItems)
                dashedDivider
                section(title: HomeLocalizedString.string("home.notifications.section.allHistory", locale: locale), items: historyItems)
            }
            .padding(.horizontal, DSConstant.mediumLarge.value)
            .padding(.bottom, DSConstant.xxLarge.value)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }

    private var backButton: some View {
        DSButton(
            title: "",
            type: .social,
            icon: .miniArrowLeft,
            widthStyle: .icon,
            accessibilityLabel: HomeLocalizedString.string("home.notifications.a11y.back", locale: locale),
            action: onBack
        )
    }

    /// Figma spec: "Sharp Grotesk SmBold 20" @ 30px — a one-off size rather than the
    /// shared `.headingLargeSemibold` (40pt, same family but used for hero/marketing
    /// headlines in onboarding/login), which read too large here.
    private var title: some View {
        Text(HomeLocalizedString.string("home.notifications.title", locale: locale))
            .font(DSFont.heading(size: 30))
            .foregroundColor(DSColor.Text.heading)
    }

    /// Single-item `DSBannerCarousel` — same live component `HomeScreen` uses for its
    /// Daily Offer banners, just with one item instead of three (no page indicator or
    /// auto-advance shows up when `items.count == 1`). Replaces the old baked-in
    /// `mockBannerDailyOffer` art now that the real banner exists.
    private var dailyOfferBanner: some View {
        DSBannerCarousel(items: [
            .init(
                id: 0,
                backgroundColor: DSColor.Background.brown,
                image: .mockPasteryImage1,
                badgeText: HomeLocalizedString.string("home.dailyOfferBanner.badge", locale: locale),
                title: dailyOfferTitle
            )
        ])
        .accessibilityLabel(HomeLocalizedString.string("home.notifications.a11y.dailyOffer", locale: locale))
    }

    /// "15%" always renders in the shared brand-orange highlight color, matching
    /// `HomeScreen.dailyOfferTitle`'s "Buy 1 get 2" idiom for its own quantities.
    private var dailyOfferTitle: Text {
        Text("15%").foregroundColor(DSColor.Text.accent)
        + Text(HomeLocalizedString.string("home.notifications.dailyOfferBanner.title.suffix", locale: locale))
            .foregroundColor(DSColor.Text.inverse)
    }

    private func section(title: String, items: [NotificationRowData]) -> some View {
        VStack(alignment: .leading, spacing: DSConstant.mediumLarge.value) {
            Text(title)
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)

            VStack(spacing: DSConstant.mediumLarge.value) {
                ForEach(items) { item in
                    notificationRow(item)
                }
            }
        }
    }

    private func notificationRow(_ item: NotificationRowData) -> some View {
        HStack(spacing: DSConstant.medium.value) {
            ZStack {
                Circle()
                    .fill(DSColor.Background.Button.disabled)
                DSIconView(
                    icon: item.icon,
                    size: Self.rowIconSize,
                    color: DSColor.Background.Button.accent
                )
            }
            .frame(width: Self.rowIconCircleSize, height: Self.rowIconCircleSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(HomeLocalizedString.string(item.titleKey, locale: locale))
                    .typography(.uiLargeBold)
                    .foregroundColor(DSColor.Text.heading)
                Text(HomeLocalizedString.string(item.dateKey, locale: locale))
                    .typography(.uiRegular)
                    .foregroundColor(DSColor.Text.secondary)
            }

            Spacer(minLength: DSConstant.small.value)

            HStack(spacing: DSConstant.xSmall.value) {
                DSIconView(
                    icon: .minitPointCoin,
                    size: Self.coinSize,
                    renderingMode: .original
                )
                Text(pointsLabel(for: item.points))
                    .typography(.uiLargeBold)
                    .foregroundColor(DSColor.Text.heading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func pointsLabel(for points: Int) -> String {
        let format = HomeLocalizedString.string("home.notifications.pointsFormat", locale: locale)
        return String(format: format, points)
    }

    private var dashedDivider: some View {
        Rectangle()
            .stroke(
                DSColor.Border.default,
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
            .frame(height: 1)
            .padding(.vertical, DSConstant.large.value)
            .accessibilityHidden(true)
    }
}

private struct NotificationRowData: Identifiable {
    let id = UUID()
    let icon: DSIcon
    let titleKey: String
    let dateKey: String
    let points: Int
}

#Preview("NotificationsScreen") {
    NotificationsScreen(onBack: {})
}
