import SwiftUI

struct FeatureUnderConstructionAlertModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "common.alert.underConstruction.title", bundle: .module),
            isPresented: $isPresented
        ) {
            Button(String(localized: "common.alert.ok", bundle: .module), role: .cancel) {}
        } message: {
            Text(String(localized: "common.alert.underConstruction.message", bundle: .module))
        }
    }
}

extension View {
    func featureUnderConstructionAlert(isPresented: Binding<Bool>) -> some View {
        modifier(FeatureUnderConstructionAlertModifier(isPresented: isPresented))
    }
}
