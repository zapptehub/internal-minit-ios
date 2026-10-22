import DesignSystem
import SwiftUI

/// Title, message, and retry for a failed first `GET /v1/home`.
///
/// Resolved against `locale`, the in-app language `HomeScreen` publishes.
/// English, Hungarian, and Slovak match Android `home_load_failed_*`.
struct HomeLoadFailureCopy: Equatable {
    let title: String
    let message: String
    let retry: String

    init(locale: Locale, bundle: Bundle = .module) {
        title = HomeLocalizedString.string("home.loadFailed.title", locale: locale, bundle: bundle)
        message = HomeLocalizedString.string("home.loadFailed.message", locale: locale, bundle: bundle)
        retry = HomeLocalizedString.string("home.loadFailed.retry", locale: locale, bundle: bundle)
    }
}

/// Assertive VoiceOver announcement for the Home failure, matching the launch
/// failure screen's `AccessibilitySpeechAnnouncementPriority.high`.
enum HomeLoadFailureAnnouncement {
    static func spoken(title: String, message: String) -> String {
        "\(title). \(message)"
    }

    static func attributed(title: String, message: String) -> AttributedString {
        var announcement = AttributedString(spoken(title: title, message: message))
        announcement.accessibilitySpeechAnnouncementPriority = .high
        return announcement
    }

    static func post(title: String, message: String) {
        AccessibilityNotification.Announcement(attributed(title: title, message: message)).post()
    }
}

/// Failure shown when the first Home load fails.
///
/// Replaces the catalog so the firebase sample is not presented as a healthy
/// Home. The warning glyph is decorative. The title is a header, and appearing
/// announces the title and message assertively. Retry is a tertiary button.
/// The column scrolls so a large text size can reach the button under the
/// header. `isRetryEnabled` is false while Home is logging out.
///
/// The header trait and the hidden warning icon are covered only by code
/// review. The package test host has no window scene, and a key
/// `UIHostingController` does not publish those traits.
struct HomeLoadFailureView: View {
    var isRetryEnabled: Bool
    var announce: (String, String) -> Void
    let onRetry: () -> Void
    @Environment(\.locale) private var locale

    init(
        isRetryEnabled: Bool = true,
        announce: @escaping (String, String) -> Void = { title, message in
            HomeLoadFailureAnnouncement.post(title: title, message: message)
        },
        onRetry: @escaping () -> Void
    ) {
        self.isRetryEnabled = isRetryEnabled
        self.announce = announce
        self.onRetry = onRetry
    }

    var body: some View {
        let copy = HomeLoadFailureCopy(locale: locale)
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: DSConstant.medium.value) {
                    HomeLoadFailureStatusIcon()
                        .accessibilityHidden(true)
                    Text(copy.title)
                        .typography(.headingMediumBold)
                        .foregroundColor(DSColor.Text.heading)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(copy.message)
                        .typography(.paragraphRegular)
                        .foregroundColor(DSColor.Text.secondary)
                        .multilineTextAlignment(.center)
                    DSButton(
                        title: copy.retry,
                        type: .tertiary,
                        isEnabled: isRetryEnabled,
                        widthStyle: .compact
                    ) {
                        onRetry()
                    }
                }
                .padding(DSConstant.large.value)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .background(DSColor.Background.Layer.level0)
        .onAppear {
            announce(copy.title, copy.message)
        }
    }
}

/// Warning glyph matching the launch-failure icon: a 48 pt circle and a 24 pt
/// triangle, error-tinted on the level-one surface. Decorative — the title
/// and message carry the meaning.
private struct HomeLoadFailureStatusIcon: View {
    /// Android `DsSize.MinimumTouchTarget` / scale 1200.
    private static let diameter: CGFloat = 48
    /// Android `DsSize.IconLarge` / scale 600.
    private static let glyphSize = DSConstant.large.value

    var body: some View {
        ZStack {
            Circle()
                .fill(DSColor.Background.Layer.level1)
                .frame(width: Self.diameter, height: Self.diameter)
            DSIconView(
                icon: .warningTriangle,
                size: Self.glyphSize,
                color: DSColor.Border.error
            )
        }
    }
}
