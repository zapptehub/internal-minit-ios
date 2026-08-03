import SwiftUI

public enum FeatureMap {
    @MainActor
    public static func createScreen() -> some View {
        MapScreen()
    }
}
