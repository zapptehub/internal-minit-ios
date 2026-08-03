import DataProfile
import SwiftUI

public enum FeatureTabRoot {
    @MainActor
    public static func createScreen(
        userId: String,
        profileRepository: ProfileRepository,
        onLogOut: @escaping () -> Void
    ) -> some View {
        TabRootView(
            userId: userId,
            profileRepository: profileRepository,
            onLogOut: onLogOut
        )
    }
}
