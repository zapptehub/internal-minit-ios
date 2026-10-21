import CoreNetworking
import DataProfile
import FeatureHome
import SwiftUI

public enum FeatureTabRoot {
    @MainActor
    public static func createScreen(
        userId: String,
        profileRepository: ProfileRepository,
        homeRepository: any HomeRepository,
        networkClient: any NetworkClient,
        apiBaseURL: String,
        onLogOut: @escaping () -> Void
    ) -> some View {
        TabRootView(
            userId: userId,
            profileRepository: profileRepository,
            homeRepository: homeRepository,
            networkClient: networkClient,
            apiBaseURL: apiBaseURL,
            onLogOut: onLogOut
        )
    }
}
