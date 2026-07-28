import SwiftUI

struct FeatureUnderConstructionAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.alert(
            LoginLocalizedString.string("common.alert.underConstruction.title", locale: locale),
            isPresented: $isPresented
        ) {
            Button(LoginLocalizedString.string("common.alert.ok", locale: locale), role: .cancel) {}
        } message: {
            Text(LoginLocalizedString.string("common.alert.underConstruction.message", locale: locale))
        }
    }
}

extension View {
    func featureUnderConstructionAlert(isPresented: Binding<Bool>) -> some View {
        modifier(FeatureUnderConstructionAlertModifier(isPresented: isPresented))
    }
}
