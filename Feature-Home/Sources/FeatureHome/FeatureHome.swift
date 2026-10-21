import CoreNetworking
import DataProfile
import SwiftUI

public enum FeatureHome {
    @MainActor
    public static func createScreen(
        userId: String,
        profileRepository: ProfileRepository,
        homeRepository: any HomeRepository,
        networkClient: any NetworkClient,
        apiBaseURL: String,
        onLogOut: @escaping () -> Void
    ) -> some View {
        HomeScreen(
            userId: userId,
            profileRepository: profileRepository,
            homeRepository: homeRepository,
            networkClient: networkClient,
            apiBaseURL: apiBaseURL,
            onLogOut: onLogOut
        )
    }
}
