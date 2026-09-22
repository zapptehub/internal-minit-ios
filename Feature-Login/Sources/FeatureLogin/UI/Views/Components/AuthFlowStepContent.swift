import SwiftUI

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
    func authFlowStepContent() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, AuthFlowStepLayout.horizontalInset)
    }
}
