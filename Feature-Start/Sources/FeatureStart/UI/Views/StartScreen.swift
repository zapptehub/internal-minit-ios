import Foundation
import SwiftUI
import DesignSystem

struct StartScreen: View {
    let analytics: StartAnalyticsTracking?
    let onGetStarted: () -> Void
    @Environment(\.locale) private var locale

    /// Matches the Figma frame's fixed top offset before the centered logo/headline group.
    /// Not a reusable DSConstant — it's a one-off screen offset, not a spacing-scale token in Figma either.
    private let topOffset: CGFloat = 60

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: topOffset)

                Spacer()

                VStack(spacing: DSConstant.xLarge.value) {
                    DSImageView(image: .minitLogo, size: CGSize(width: 105.238, height: 105.238))
                        .accessibilityHidden(true)

                    Text(StartLocalizedString.string("start.headline", locale: locale))
                        .typography(.headingLargeBold)
                        .foregroundColor(DSColor.Text.inverse)
                        .multilineTextAlignment(.center)
                        .tracking(-1.68)
                }

                Spacer()

                bottomContainer
            }
        }
        .onAppear {
            analytics?.trackScreenOpened(file: #fileID)
        }
    }

    private var backgroundLayer: some View {
        // GeometryReader caps the image's *reported* layout size to the space actually
        // available. Without it, `scaledToFill()` on a `resizable()` image can request an
        // ideal size larger than the screen (to satisfy the fill aspect ratio), and since
        // `.clipped()` only clips painted pixels — not the reported layout size — that
        // oversized footprint propagates up through the ZStack and pushes the button/text
        // past the real screen edges.
        GeometryReader { geometry in
            DSImage.startHero.image
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }

    private var bottomContainer: some View {
        VStack(spacing: DSConstant.large.value) {
            DSButton(
                title: StartLocalizedString.string("start.button.getStarted", locale: locale),
                type: .primary
            ) {
                analytics?.trackGetStartedTapped(file: #fileID)
                onGetStarted()
            }

            Text(legalAttributedString)
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.inverse)
                .tint(DSColor.Text.inverse)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DSConstant.xxLarge.value)
        .padding(.bottom, DSConstant.xxLarge.value)
        .frame(maxWidth: .infinity)
    }

    /// "terms" and "privacy policy" are markdown links in `start.legal` (see Localizable.xcstrings).
    /// SwiftUI keeps them tappable automatically, but doesn't bold/underline links by default —
    /// so those runs get the styling applied explicitly here to match the Figma spec.
    ///
    /// Resolves the raw markdown source via `StartLocalizedString` (locale-aware, unlike
    /// `AttributedString(localized:bundle:)`) and parses it manually, since that's the only way
    /// to get both an explicit `Locale` and markdown link parsing at once.
    private var legalAttributedString: AttributedString {
        let raw = StartLocalizedString.string("start.legal", locale: locale)
        var attributed = (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
        for run in attributed.runs where run.link != nil {
            attributed[run.range].font = FontType.paragraphBold.font
            attributed[run.range].underlineStyle = .single
        }
        return attributed
    }
}

#Preview {
    StartScreen(analytics: nil, onGetStarted: {})
}
