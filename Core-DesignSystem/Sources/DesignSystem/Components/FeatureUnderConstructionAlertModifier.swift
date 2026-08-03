import CoreExtensions
import SwiftUI

/// Shared “under construction” alert used wherever a feature is not yet available.
private struct FeatureUnderConstructionAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.alert(
            DesignSystemLocalizedString.string("common.alert.underConstruction.title", locale: locale),
            isPresented: $isPresented
        ) {
            Button(DesignSystemLocalizedString.string("common.alert.ok", locale: locale), role: .cancel) {}
        } message: {
            Text(DesignSystemLocalizedString.string("common.alert.underConstruction.message", locale: locale))
        }
    }
}

public extension View {
    /// Presents the shared under-construction alert when `isPresented` is `true`.
    func featureUnderConstructionAlert(isPresented: Binding<Bool>) -> some View {
        modifier(FeatureUnderConstructionAlertModifier(isPresented: isPresented))
    }
}


