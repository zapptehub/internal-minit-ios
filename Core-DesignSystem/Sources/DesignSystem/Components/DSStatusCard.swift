import SwiftUI

/// Generic async-operation result card — a centered loading spinner or success glyph
/// above a title/subtitle, on a white rounded surface. Used for onboarding's
/// create/claim-loyalty-card processing → success presentation, and any future
/// "doing something, then confirming it worked" moment.
///
/// The loading glyph is the branded `DSProgressView` (rotating `miniLoader`), not the
/// system `ProgressView()`. The success-icon composition (`Background/Icon/Success`
/// circle + `minitCheckbox`) mirrors `PasswordChangedScreen`'s hand-rolled version in
/// `Feature-Login` — this is the shared home for that pattern per the DRY rule (a
/// pattern appearing in 2+ modules gets extracted).
///
/// Spacing, radius, and type come from `StatusCardMetrics` (Figma status card on
/// Create Card). The shadow stays `DSShadow.card`; Figma's two-layer "Medium"
/// effect has no matching token.
public struct DSStatusCard: View {
    public enum State {
        case loading(title: String, subtitle: String?)
        case success(title: String)
    }

    let state: State

    /// `Font.custom(_:size:)` scales with the body text style. Scaling this
    /// gap the same way keeps baseline-to-baseline at 23/20 of the resolved
    /// line box (23pt when the title is 20pt).
    @ScaledMetric(relativeTo: .body) private var titleLineSpacing = StatusCardMetrics.titleLineSpacing

    public init(state: State) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: StatusCardMetrics.iconToTextSpacing) {
            icon

            VStack(spacing: StatusCardMetrics.titleToSubtitleSpacing) {
                SharpGroteskCapTrim(followingGap: titleFollowingGap) {
                    Text(title)
                        .typography(StatusCardMetrics.titleStyle)
                        .lineSpacing(titleLineSpacing)
                        .foregroundColor(StatusCardMetrics.titleColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if let subtitle {
                    Text(subtitle)
                        .typography(StatusCardMetrics.subtitleStyle)
                        .foregroundColor(StatusCardMetrics.subtitleColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(StatusCardMetrics.contentPadding)
        .background(StatusCardMetrics.surface)
        .cornerRadius(StatusCardMetrics.cornerRadius)
        .dsShadow(StatusCardMetrics.shadow)
    }

    /// Space under the title the cap trim may paint descenders into.
    /// Loading uses the 8pt title→subtitle gap. Success has no subtitle, so
    /// the card's own padding is that space.
    private var titleFollowingGap: CGFloat {
        subtitle == nil ? StatusCardMetrics.contentPadding : StatusCardMetrics.titleToSubtitleSpacing
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .loading:
            DSProgressView(
                diameter: StatusCardMetrics.iconDiameter,
                iconSize: StatusCardMetrics.glyphSize
            )
        case .success:
            Circle()
                .fill(DSColor.Background.Icon.success)
                .frame(width: StatusCardMetrics.iconDiameter, height: StatusCardMetrics.iconDiameter)
                .overlay {
                    DSIconView(
                        icon: .minitCheckbox,
                        size: StatusCardMetrics.glyphSize,
                        renderingMode: .original
                    )
                }
                .accessibilityHidden(true)
        }
    }

    private var title: String {
        switch state {
        case .loading(let title, _): return title
        case .success(let title): return title
        }
    }

    private var subtitle: String? {
        switch state {
        case .loading(_, let subtitle): return subtitle
        case .success: return nil
        }
    }
}

/// Figma status-card metrics, mapped onto existing tokens.
///
/// Internal so tests can assert the choice. Figma sizes that are not on the
/// type scale take the nearest `FontType`.
enum StatusCardMetrics {
    /// Figma padding 32. `DSConstant.xLarge`.
    static let contentPadding = DSConstant.xLarge.value
    /// Figma icon→text gap 24. `DSConstant.large`.
    static let iconToTextSpacing = DSConstant.large.value
    /// Figma title→subtitle gap 8. `DSConstant.small`.
    static let titleToSubtitleSpacing = DSConstant.small.value
    /// Figma corner radius 20. `DSConstant.cardCornerRadius`.
    static let cornerRadius = DSConstant.cardCornerRadius.value
    static let iconDiameter = DSComponentMetric.Progress.diameter
    static let glyphSize = DSComponentMetric.Progress.iconSize
    /// Figma surface/primary `#FFFFFF`.
    static let surface = DSColor.Background.Layer.level0
    /// Figma Sharp Grotesk 18. `headingMediumBold` is 20 (+2). No Sharp Grotesk
    /// style sits between `headingLargeSemibold` (40) and this 20.
    static let titleStyle = FontType.headingMediumBold
    /// Point size of `titleStyle`. SwiftUI's line box for this face is
    /// `ascender − descender`, which equals the point size (hhea lineGap is
    /// not included).
    static let titlePointSize: CGFloat = 20
    /// Figma 6166:4509 line-height "normal" is 22.95px at 18px
    /// ((ascender 800 + descender 200 + lineGap 275) / 1000). Matching that
    /// 127.5% ratio at 20pt would be 25.5 and would push the success card
    /// past Figma's 172. Use the absolute 23pt baseline spacing instead.
    static let titleBaselineToBaseline: CGFloat = 23
    /// What `.lineSpacing` adds between the style's own line boxes.
    static let titleLineSpacing: CGFloat = titleBaselineToBaseline - titlePointSize
    /// `#331A00`.
    static let titleColor = DSColor.Text.heading
    /// Figma Body/Medium/small is system medium 14 / line-height 20.
    /// `bodyMediumSmall` is that style, including the 20-high line box.
    /// `paragraphRegular` stays system regular 15.
    static let subtitleStyle = FontType.bodyMediumSmall
    /// Figma `text/body` `#666666` is `DSColor.Text.secondary` (grey 600).
    static let subtitleColor = DSColor.Text.secondary
    /// Figma effect "Medium" is two drops (`#3E3445` at 4% and 12%). No
    /// `DSShadow` token matches. The shared card shadow stays.
    static let shadow = DSShadow.card
}

#Preview("DSStatusCard — loading") {
    DSStatusCard(state: .loading(title: "Creating loyalty card...", subtitle: "This may take a second"))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
}

#Preview("DSStatusCard — success") {
    DSStatusCard(state: .success(title: "Loyalty card was added successfully"))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
}
