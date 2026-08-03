import DataProfile
import SwiftUI

public enum FeatureHome {
    @MainActor
    public static func createScreen(
        userId: String,
        profileRepository: ProfileRepository,
        onLogOut: @escaping () -> Void
    ) -> some View {
        HomeScreen(
            userId: userId,
            profileRepository: profileRepository,
            onLogOut: onLogOut
        )
    }
}
