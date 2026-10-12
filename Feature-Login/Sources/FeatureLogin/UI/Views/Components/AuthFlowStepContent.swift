import SwiftUI
import DesignSystem

/// Measurements specific to the Login sheet, derived from Figma node `6161:2121`.
///
/// This must not reuse the app-wide `defaultSidePadding()`: Login's form wrapper
/// deliberately uses a narrower 20 pt inset.
enum AuthFlowStepLayout {
    static let horizontalInset: CGFloat = 20
}

extension View {
    /// Layout wrapper for every step pushed inside `LoginScreen`'s `NavigationStack`.
    /// Horizontal padding lives on each step (not on the stack itself) so push/pop
    /// transitions slide edge-to-edge; content uses Figma's 20 pt form inset.
    ///
    func authFlowStepContent() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, AuthFlowStepLayout.horizontalInset)
    }
}

/// Above the default content size, `top` scrolls and `actions` stay on screen.
/// At `.large` and below this is the original top-to-bottom stack plus a spacer.
struct AuthFlowLargeLayout<Top: View, Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var top: () -> Top
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        if dynamicTypeSize > .large {
            DSLargeTextScroll(spacing: DSConstant.large.value) {
                top()
            } bottom: {
                actions()
            }
        } else {
            VStack(alignment: .leading, spacing: DSConstant.large.value) {
                top()
                actions()
                Spacer()
            }
        }
    }
}
