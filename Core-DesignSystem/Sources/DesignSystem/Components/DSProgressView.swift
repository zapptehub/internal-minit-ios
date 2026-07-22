import SwiftUI

/// Branded replacement for the system `ProgressView()` circular spinner — renders the
/// `miniLoader` glyph (8 tapered spokes) and continuously rotates it 360° while visible,
/// matching the design's loading-state look everywhere the app shows an indeterminate
/// spinner (e.g. `DSStatusCard`'s loading state).
///
/// The appear/disappear-driven state toggle (rather than attaching a `repeatForever`
/// animation directly at init) is the standard SwiftUI pattern for animations that must
/// restart correctly if the view is removed and re-added to the hierarchy.
public struct DSProgressView: View {
    @State private var isRotating = false

    public var size: CGFloat
    public var color: Color

    private static let rotationDuration: Double = 0.9

    public init(size: CGFloat = 24, color: Color = DSColor.Icon.primary) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        DSIconView(icon: .miniLoader, size: size, color: color)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                isRotating
                    ? .linear(duration: Self.rotationDuration).repeatForever(autoreverses: false)
                    : nil,
                value: isRotating
            )
            .onAppear { isRotating = true }
            .onDisappear { isRotating = false }
            .accessibilityHidden(true)
    }
}

#Preview("DSProgressView") {
    VStack(spacing: DSConstant.large.value) {
        DSProgressView()
        DSProgressView(size: 48)
    }
    .padding()
    .background(
        Circle()
            .fill(Color(white: 0.93))
            .frame(width: 160, height: 160)
    )
}
