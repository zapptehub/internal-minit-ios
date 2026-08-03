import SwiftUI

public enum FeatureHome {
    @MainActor
    public static func createScreen(onLogOut: @escaping () -> Void) -> some View {
        HomeScreen(onLogOut: onLogOut)
    }
}
