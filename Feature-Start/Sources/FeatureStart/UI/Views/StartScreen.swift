import Foundation
import SwiftUI
import DesignSystem

struct StartScreen: View {
    let analytics: StartAnalyticsTracking?
    /// Gates the secondary "Try Minit in Demo mode" button — `true` only on http-backend
    /// builds (`AppDependencies.showsDemo`; see `MinitDemoEnabled` in Info.plist).
    let showsDemo: Bool
    let onGetStarted: () -> Void
    /// Fired by the demo confirmation alert's Continue button. The actual
    /// `POST /v1/demo/session` call and post-login routing happen outside this module
    /// (`AppFlowViewModel.startDemo()`) — `Core-Networking` isn't a `FeatureStart`
    /// dependency. Cancel does nothing.
    let onDemoContinue: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsDemoConfirmation = false

    init(
        analytics: StartAnalyticsTracking?,
        showsDemo: Bool = false,
        onGetStarted: @escaping () -> Void,
        onDemoContinue: @escaping () -> Void = {}
    ) {
        self.analytics = analytics
        self.showsDemo = showsDemo
        self.onGetStarted = onGetStarted
        self.onDemoContinue = onDemoContinue
    }

    /// Matches the Figma frame's fixed top offset before the centered logo/headline group.
    /// Not a reusable DSConstant — it's a one-off screen offset, not a spacing-scale token in Figma either.
    private let topOffset: CGFloat = 60

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            if dynamicTypeSize > .large {
                DSLargeTextScroll(spacing: 0) {
                    VStack(spacing: DSConstant.xLarge.value) {
                        DSImageView(image: .minitLogo, size: CGSize(width: 105.238, height: 105.238))
                            .accessibilityHidden(true)
                            .padding(.top, topOffset)

                        DSGrowingText(
                            text: StartLocalizedString.string("start.headline", locale: locale),
                            type: .headingLargeBold,
                            color: DSColor.Text.inverse,
                            alignment: .center
                        )
                        .accessibilityAddTraits(.isHeader)
                    }
                    .frame(maxWidth: .infinity)
                } bottom: {
                    bottomContainer
                }
            } else {
                contentStack
            }
        }
        .onAppear {
            analytics?.trackScreenOpened(file: #fileID)
        }
        .alert(
            StartLocalizedString.string("start.demo.alert.title", locale: locale),
            isPresented: $showsDemoConfirmation
        ) {
            Button(DesignSystemLocalizedString.string("common.alert.cancel", locale: locale), role: .cancel) {}
            Button(DesignSystemLocalizedString.string("common.alert.continue", locale: locale)) {
                onDemoContinue()
            }
        } message: {
            Text(StartLocalizedString.string("start.demo.alert.message", locale: locale))
        }
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: topOffset)

            Spacer()

            VStack(spacing: DSConstant.xLarge.value) {
                DSImageView(image: .minitLogo, size: CGSize(width: 105.238, height: 105.238))
                    .accessibilityHidden(true)

                DSGrowingText(
                    text: StartLocalizedString.string("start.headline", locale: locale),
                    type: .headingLargeBold,
                    color: DSColor.Text.inverse,
                    alignment: .center
                )
                .accessibilityAddTraits(.isHeader)
            }

            Spacer()

            bottomContainer
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
                .accessibilityHidden(true)
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

            if showsDemo {
                // Same size as Get started. Near-black fill is `.tertiary`'s
                // `Background.Button.tertiary` (#000000); `.darkOrange` exists because
                // that type forces a white label. Label is `darkOrangeButtonLabel`
                // (`Minit.tone600`, #CE6900).
                DSButton(
                    title: StartLocalizedString.string("start.button.tryDemo", locale: locale),
                    type: .darkOrange
                ) {
                    showsDemoConfirmation = true
                }
            }

            Text(legalAttributedString)
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.inverse)
                .tint(DSColor.Text.inverse)
                .multilineTextAlignment(.center)
                .uncompressedWhenTextIsLarge()
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
            attributed[run.range].font = FontType.paragraphBold.scaledSystemFont(for: dynamicTypeSize)
            attributed[run.range].underlineStyle = .single
        }
        return attributed
    }
}

#Preview {
    StartScreen(analytics: nil, onGetStarted: {})
}

#Preview("Demo mode") {
    StartScreen(analytics: nil, showsDemo: true, onGetStarted: {})
}
