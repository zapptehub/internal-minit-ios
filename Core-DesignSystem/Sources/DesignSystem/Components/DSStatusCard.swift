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
public struct DSStatusCard: View {
    public enum State {
        case loading(title: String, subtitle: String?)
        case success(title: String)
    }

    let state: State

    private static let iconDiameter: CGFloat = 48
    private static let glyphSize: CGFloat = 24

    public init(state: State) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: DSConstant.medium.value) {
            icon

            VStack(spacing: DSConstant.xSmall.value) {
                Text(title)
                    .typography(.uiLargeBold)
                    .foregroundColor(DSColor.Text.heading)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .typography(.paragraphRegular)
                        .foregroundColor(DSColor.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DSConstant.large.value)
        .background(DSColor.Background.Layer.level0)
        .cornerRadius(DSConstant.medium.value)
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .loading:
            DSProgressView(size: Self.iconDiameter)
        case .success:
            Circle()
                .fill(DSColor.Background.Icon.success)
                .frame(width: Self.iconDiameter, height: Self.iconDiameter)
                .overlay {
                    DSIconView(icon: .minitCheckbox, size: Self.glyphSize, renderingMode: .original)
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
