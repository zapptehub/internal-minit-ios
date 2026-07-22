import SwiftUI

/// Branded replacement for the system `ProgressView()` circular spinner: a filled
/// neutral-gray circle (`Background/Icon/Loading`, `#EDEDED`) with the `miniLoader`
/// glyph centered inside it, continuously rotating 360° while visible. Defaults
/// (48pt circle / 24pt glyph) match the reference screenshot exactly and mirror
/// `DSStatusCard`'s success composition (filled circle + centered glyph, just gray
/// instead of green and spinning instead of a static checkmark).
///
/// The appear/disappear-driven state toggle (rather than attaching a `repeatForever`
/// animation directly at init) is the standard SwiftUI pattern for animations that must
/// restart correctly if the view is removed and re-added to the hierarchy.
public struct DSProgressView: View {
    @State private var isRotating = false

    public var diameter: CGFloat
    public var iconSize: CGFloat
    public var backgroundColor: Color
    public var iconColor: Color

    /// Full rotation duration — deliberately slow/calm, not a fast "busy" spin.
    private static let rotationDuration: Double = 1.6

    public init(
        diameter: CGFloat = 48,
        iconSize: CGFloat = 24,
        backgroundColor: Color = DSColor.Background.Icon.loading,
        iconColor: Color = DSColor.Icon.primary
    ) {
        self.diameter = diameter
        self.iconSize = iconSize
        self.backgroundColor = backgroundColor
        self.iconColor = iconColor
    }

    public var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: diameter, height: diameter)
            .overlay {
                DSIconView(icon: .miniLoader, size: iconSize, color: iconColor)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(
                        isRotating
                            ? .linear(duration: Self.rotationDuration).repeatForever(autoreverses: false)
                            : nil,
                        value: isRotating
                    )
            }
            .onAppear { isRotating = true }
            .onDisappear { isRotating = false }
            .accessibilityHidden(true)
    }
}

#Preview("DSProgressView") {
    VStack(spacing: DSConstant.large.value) {
        DSProgressView()
        DSProgressView(diameter: 72, iconSize: 36)
    }
    .padding()
}
