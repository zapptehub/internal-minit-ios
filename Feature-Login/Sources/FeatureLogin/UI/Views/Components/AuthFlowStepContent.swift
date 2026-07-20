import SwiftUI
import DesignSystem

extension View {
    /// Layout wrapper for every step pushed inside `LoginScreen`'s `NavigationStack`.
    /// Horizontal padding lives on each step (not on the stack itself) so push/pop
    /// transitions slide edge-to-edge; content stays inset via `defaultSidePadding()`.
    func authFlowStepContent() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .defaultSidePadding()
    }
}
