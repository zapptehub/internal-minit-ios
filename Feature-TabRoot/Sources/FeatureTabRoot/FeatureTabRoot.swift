import SwiftUI

public enum FeatureTabRoot {
    @MainActor
    public static func createScreen(onLogOut: @escaping () -> Void) -> some View {
        TabRootView(onLogOut: onLogOut)
    }
}
