import SwiftUI
import UIKit
import DesignSystem

/// Standalone success screen presented in its own sheet after a successful password-reset OTP
/// confirm — see `FeatureLogin.createPasswordChangedScreen(onBackToLogin:)` and
/// `plans/password_changed_second_sheet_9f2e404f.plan.md`. Deliberately has no
/// `AuthFlowNavigationBar` logo — the login sheet has already fully dismissed by the time this
/// appears, so there's no shared nav chrome to anchor against.
///
/// Sized to its own content (rather than the sheet's default near-full-height): the content
/// reports its intrinsic height back up via `ContentHeightPreferenceKey`, which drives
/// `.presentationDetents`, capped at half the screen so it can never grow past that even with
/// larger Dynamic Type sizes.
struct PasswordChangedScreen: View {
    let analytics: LoginAnalyticsTracking
    let onBackToLogin: () -> Void
    @Environment(\.locale) private var locale

    @State private var sheetHeight: CGFloat = .zero

    private let successIconDiameter: CGFloat = 48
    private let successGlyphSize: CGFloat = 24
    private let iconToHeadlineSpacing: CGFloat = DSConstant.large.value

    var body: some View {
        content
            .presentationDetents([.height(sheetHeight)])
            .presentationBackground(DSColor.Background.Layer.level0)
            .onPreferenceChange(ContentHeightPreferenceKey.self) { contentHeight in
                sheetHeight = contentHeight
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            successIcon

            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text(LoginLocalizedString.string("passwordChanged.headline", locale: locale))
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.heading)

                Text(LoginLocalizedString.string("passwordChanged.subtitle", locale: locale))
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.secondary)
            }
            .padding(.top, iconToHeadlineSpacing)

            DSButton(
                title: LoginLocalizedString.string("passwordChanged.button.backToLogin", locale: locale),
                type: .tertiary
            ) {
                analytics.trackPasswordChangedBackToLoginTapped(file: #fileID)
                onBackToLogin()
            }
            .padding(.top, DSConstant.large.value)
        }
        .defaultSidePadding()
        .padding(.top, AuthFlowNavigationBar.topPadding)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ContentHeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var successIcon: some View {
        Circle()
            .fill(DSColor.Background.Icon.success)
            .frame(width: successIconDiameter, height: successIconDiameter)
            .overlay {
                DSIconView(icon: .minitCheckbox, size: successGlyphSize, renderingMode: .original)
            }
            .accessibilityHidden(true)
    }
}

private struct ContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    PasswordChangedScreen(analytics: PreviewLoginAnalyticsTracking(), onBackToLogin: {})
}
