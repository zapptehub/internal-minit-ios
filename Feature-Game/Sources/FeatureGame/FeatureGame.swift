import SwiftUI

public enum FeatureGame {
    @MainActor
    public static func createScreen() -> some View {
        GameScreen()
    }
}
