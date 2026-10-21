import DesignSystem
import SwiftUI

/// Notifications list opened from Home's bell. All rows and the Daily Offer banner are
/// hardcoded mocks until a real notifications feed and pressable banner land.
///
/// Layout follows Figma "AMP / Notifications" (node 4088:1319); the values live in
/// `NotificationsScreenMetrics`.
struct NotificationsScreen: View {
    let onBack: () -> Void
    /// Daily-offer banner tap. `nil` keeps `DSBannerCarousel`'s own alert, which
    /// is what the layout tests render. Home passes a closure and presents the
    /// alert from `showsUnderConstructionAlert` so it stays above this cover.
    var onDailyOfferTap: (() -> Void)? = nil
    var showsUnderConstructionAlert: Binding<Bool> = .constant(false)

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var sectionTitleLineBox = NotificationsScreenMetrics.sectionTitleLineBox

    private let todayItems: [NotificationRowData] = [
        .init(icon: .minitIcBaguette, titleKey: "home.notifications.row.firstScan", dateKey: "home.notifications.date.june12", points: 45),
        .init(icon: .minitIcBretzel, titleKey: "home.notifications.row.newProduct", dateKey: "home.notifications.date.june11", points: 45)
    ]

    private let historyItems: [NotificationRowData] = [
        .init(icon: .minitIcBaguette, titleKey: "home.notifications.row.firstScan", dateKey: "home.notifications.date.june12", points: 45),
        .init(icon: .minitIcBretzel, titleKey: "home.notifications.row.newProduct", dateKey: "home.notifications.date.june11", points: 45),
        .init(icon: .minitIcBretzel, titleKey: "home.notifications.row.newProduct", dateKey: "home.notifications.date.june11", points: 45)
    ]

    private typealias Metrics = NotificationsScreenMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                backButton
                    .padding(.top, Metrics.headerTopSpacing - Metrics.backTapTargetInset)
                    .padding(.leading, Metrics.horizontalInset - Metrics.backTapTargetInset)
                title
                    .padding(.top, Metrics.backButtonToTitleSpacing - Metrics.backTapTargetInset)
                    .padding(.horizontal, Metrics.horizontalInset)
                VStack(alignment: .leading, spacing: Metrics.columnSpacing) {
                    dailyOfferBanner
                    section(title: HomeLoyaltyCopy.sectionTitle("today", locale: locale), items: todayItems)
                    dashedDivider
                    section(title: HomeLoyaltyCopy.sectionTitle("history", locale: locale), items: historyItems)
                }
                .padding(.top, Metrics.titleToBannerSpacing)
                .padding(.horizontal, Metrics.horizontalInset)
            }
            // Figma keeps 104 between the last row's frame and the bottom of the screen, so
            // the scroll content ignores the bottom safe area and pads by that amount itself.
            .padding(.bottom, Metrics.bottomSpacing)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }

    /// Figma "BackOnly" header (4164:5459): a 40pt white circle with a 1pt
    /// `border/primary` (#E6E6E6) outline and a 16pt arrow, centred in a 44pt tap area.
    private var backButton: some View {
        Button(action: onBack) {
            DSIconView(icon: .miniArrowLeft, size: Metrics.backIconSize, color: DSColor.Text.primary)
                .frame(width: Metrics.backCircleSize, height: Metrics.backCircleSize)
                .background(Circle().fill(DSColor.Background.Layer.level0))
                .overlay(Circle().strokeBorder(DSColor.Border.default, lineWidth: Metrics.backBorderWidth))
                .frame(width: Metrics.backTapTargetSize, height: Metrics.backTapTargetSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(HomeLocalizedString.string("home.notifications.a11y.back", locale: locale))
    }

    /// Figma "Page Title" (6123:1790): Sharp Grotesk SmBold 20 at 30pt, `#331A00`.
    /// `headingH2` is that face and size with the 38pt line box.
    private var title: some View {
        DSGrowingText(
            text: HomeLoyaltyCopy.sectionTitle("notifications", locale: locale),
            type: .headingH2,
            color: DSColor.Text.heading
        )
        .accessibilityAddTraits(.isHeader)
    }

    /// Single-item `DSBannerCarousel` — same live component `HomeScreen` uses for its
    /// Daily Offer banners, just with one item instead of three (no page indicator or
    /// auto-advance shows up when `items.count == 1`). The Figma "Small" drop shadow comes
    /// from `DSBannerCarousel` itself, as on Home.
    /// The banner's own id, after Home's daily offers 0, 1 and 2 (Android uses the same).
    static let dailyOfferBannerID = 3

    @ViewBuilder
    private var dailyOfferBanner: some View {
        if onDailyOfferTap == nil {
            dailyOfferCarousel
        } else {
            dailyOfferCarousel.featureUnderConstructionAlert(isPresented: showsUnderConstructionAlert)
        }
    }

    private var dailyOfferCarousel: some View {
        DSBannerCarousel(
            items: [
                .init(
                    id: Self.dailyOfferBannerID,
                    backgroundColor: DSColor.Background.brown,
                    image: .mockPasteryImage1,
                    badgeText: HomeLocalizedString.string("home.dailyOfferBanner.badge", locale: locale),
                    title: dailyOfferTitle
                )
            ],
            onBannerTap: onDailyOfferTap,
            accessibilityLabel: Self.dailyOfferAccessibilityLabel(locale: locale)
        )
    }

    /// "15%" always renders in the shared brand-orange highlight color, matching
    /// `HomeScreen.dailyOfferTitle`'s "Buy 1 get 2" idiom for its own quantities.
    /// VoiceOver uses the same characters as the visible title.
    private static let dailyOfferPercent = "15%"

    static func dailyOfferPlainTitle(locale: Locale) -> String {
        dailyOfferPercent + dailyOfferTitleSuffix(locale: locale)
    }

    /// "Daily Offer, 15% Off on every coffee" — the carousel override replaces
    /// the badge and title, so this label has to carry both.
    static func dailyOfferAccessibilityLabel(locale: Locale) -> String {
        NotificationsDailyOfferAccessibility.label(
            offerName: HomeLocalizedString.string("home.notifications.a11y.dailyOffer", locale: locale),
            offerTitle: dailyOfferPlainTitle(locale: locale)
        )
    }

    private static func dailyOfferTitleSuffix(locale: Locale) -> String {
        HomeLocalizedString.string("home.notifications.dailyOfferBanner.title.suffix", locale: locale)
    }

    private var dailyOfferTitle: Text {
        Text(Self.dailyOfferPercent).foregroundColor(DSColor.Text.accent)
        + Text(Self.dailyOfferTitleSuffix(locale: locale))
            .foregroundColor(DSColor.Text.inverse)
    }

    /// Figma "Recent Activity" (6078:4494): 18pt Sharp Grotesk title, 12 to the rows,
    /// rows 20 apart.
    private func section(title: String, items: [NotificationRowData]) -> some View {
        VStack(alignment: .leading, spacing: Metrics.sectionTitleToRowsSpacing) {
            Text(title)
                .typography(.headingSection)
                .foregroundColor(DSColor.Text.heading)
                .frame(minHeight: sectionTitleLineBox)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: Metrics.rowSpacing) {
                ForEach(items) { item in
                    NotificationRow(
                        item: item,
                        pointsLabel: pointsLabel(for: item.points)
                    )
                }
            }
        }
    }

    private func pointsLabel(for points: Int) -> String {
        HomeLoyaltyCopy.pointsBadge(points, locale: locale)
    }

    /// Figma line 4088:1695, 24 above and below (the column spacing).
    private var dashedDivider: some View {
        Rectangle()
            .stroke(
                DSColor.Border.default,
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// One VoiceOver label for the notifications Daily Offer banner.
///
/// The carousel override replaces badge and title, so the spoken name has to
/// carry both: "Daily Offer, 15% Off on every coffee".
enum NotificationsDailyOfferAccessibility {
    static func label(offerName: String, offerTitle: String) -> String {
        let name = offerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = offerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return title }
        if title.isEmpty { return name }
        return "\(name), \(title)"
    }
}

/// Figma "AMP / Notifications" (4088:1319) values for `NotificationsScreen`.
enum NotificationsScreenMetrics {
    static let horizontalInset: CGFloat = 20
    /// The 40pt back circle sits 10 below the safe area (Figma header top 72 under a 62
    /// status bar).
    static let headerTopSpacing: CGFloat = 10
    static let backCircleSize: CGFloat = 40
    static let backIconSize: CGFloat = 16
    static let backBorderWidth: CGFloat = 1
    static let backTapTargetSize: CGFloat = 44
    static let backTapTargetInset: CGFloat = (backTapTargetSize - backCircleSize) / 2
    /// Header bottom padding 8 + BODY top padding 16.
    static let backButtonToTitleSpacing: CGFloat = 24
    /// BODY gap.
    static let titleToBannerSpacing: CGFloat = 16
    /// "Scans" column gap: banner, Today, divider, All History.
    static let columnSpacing: CGFloat = 24
    /// Figma sets the 18pt section titles at Sharp Grotesk's "normal" line height (23pt);
    /// `headingSection` itself has no line box (it is trimmed where Home uses it).
    static let sectionTitleLineBox: CGFloat = 23
    static let sectionTitleToRowsSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 20
    static let iconCircleSize: CGFloat = 40
    static let iconSize: CGFloat = 24
    static let iconToTextSpacing: CGFloat = 12
    static let rowLineHeight: CGFloat = 20
    static let rowTitlePointSize: CGFloat = 16
    static let coinSize: CGFloat = 16
    static let coinToPointsSpacing: CGFloat = 8
    /// Figma frame bottom padding, measured from the bottom of the screen.
    static let bottomSpacing: CGFloat = 104
}

/// One Figma "Content" row (6078:4499): 40pt grey circle with a 24pt orange icon, title
/// (Body/Medium/md 16/20, `text/headings` #1A1A1A) over date (Body/Medium/label 12/20,
/// `text/disabled` #B3B3B3), and the coin plus "+45 pts" (Body/Bold/label 12/20) 8 apart.
struct NotificationRow: View {
    let item: NotificationRowData
    let pointsLabel: String

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var lineHeight = NotificationsScreenMetrics.rowLineHeight
    @ScaledMetric(relativeTo: .body) private var titlePointSize = NotificationsScreenMetrics.rowTitlePointSize

    private typealias Metrics = NotificationsScreenMetrics

    var body: some View {
        HStack(spacing: Metrics.iconToTextSpacing) {
            ZStack {
                Circle()
                    .fill(DSColor.Background.Button.disabled)
                DSIconView(
                    icon: item.icon,
                    size: Metrics.iconSize,
                    color: DSColor.Background.Button.accent
                )
            }
            .frame(width: Metrics.iconCircleSize, height: Metrics.iconCircleSize)

            VStack(alignment: .leading, spacing: 0) {
                Text(HomeLocalizedString.string(item.titleKey, locale: locale))
                    .font(.system(size: titlePointSize, weight: .medium))
                    .foregroundColor(DSColor.Text.primary)
                    .frame(minHeight: lineHeight)
                Text(HomeLocalizedString.string(item.dateKey, locale: locale))
                    .typography(.uiCaptionMedium)
                    .foregroundColor(DSColor.Text.disabled)
                    .frame(minHeight: lineHeight)
            }

            Spacer(minLength: DSConstant.small.value)

            HStack(spacing: Metrics.coinToPointsSpacing) {
                DSIconView(
                    icon: .minitPointCoin,
                    size: Metrics.coinSize,
                    renderingMode: .original
                )
                Text(pointsLabel)
                    .typography(.bodyBoldLabel)
                    .foregroundColor(DSColor.Text.primary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct NotificationRowData: Identifiable {
    let id = UUID()
    let icon: DSIcon
    let titleKey: String
    let dateKey: String
    let points: Int
}

#Preview("NotificationsScreen") {
    NotificationsScreen(onBack: {})
}
