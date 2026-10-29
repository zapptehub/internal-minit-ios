import CoreNetworking
import DataProfile
import DesignSystem
import FeatureCard
import FeatureGame
import FeatureHome
import FeatureMap
import FeatureOffers
import SwiftUI

struct TabRootView: View {
    let userId: String
    let profileRepository: ProfileRepository
    let homeRepository: any HomeRepository
    let networkClient: any NetworkClient
    let apiBaseURL: String
    let onLogOut: () -> Void
    @State private var selectedTab: AppTab = .home

    @Environment(\.locale) private var locale

    var body: some View {
        TabView(selection: $selectedTab) {
            FeatureHome.createScreen(
                userId: userId,
                profileRepository: profileRepository,
                homeRepository: homeRepository,
                networkClient: networkClient,
                apiBaseURL: apiBaseURL,
                onLogOut: onLogOut
            )
                .tabItem { tabLabel(for: .home) }
                .tag(AppTab.home)

            FeatureOffers.createScreen()
                .tabItem { tabLabel(for: .offers) }
                .tag(AppTab.offers)

            FeatureMap.createScreen()
                .tabItem { tabLabel(for: .map) }
                .tag(AppTab.map)

            FeatureCard.createScreen()
                .tabItem { tabLabel(for: .card) }
                .tag(AppTab.card)

            FeatureGame.createScreen()
                .tabItem { tabLabel(for: .game) }
                .tag(AppTab.game)
        }
        .tint(DSColor.Background.Button.secondary)
        // Popups from the tabs (Home's loyalty card) draw above the tab bar, centred on
        // the full screen, with the scrim covering the tab bar like Android.
        .dsPopupHost()
        .onAppear {
            DiagnosticLines.line("route tab \(selectedTab.rawValue)")
        }
        .onChange(of: selectedTab) { _, tab in
            DiagnosticLines.line("route tab \(tab.rawValue)")
        }
    }

    @ViewBuilder
    private func tabLabel(for tab: AppTab) -> some View {
        (selectedTab == tab ? tab.selectedIcon : tab.unselectedIcon).image
        Text(DesignSystemLocalizedString.string(tab.titleKey, locale: locale))
    }
}
