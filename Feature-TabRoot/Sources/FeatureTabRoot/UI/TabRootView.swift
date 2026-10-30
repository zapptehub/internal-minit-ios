import CoreNetworking
import DataProfile
import DesignSystem
import FeatureCard
import FeatureGame
import FeatureHome
import FeatureMap
import FeatureOffers
import SwiftUI
import UIKit

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
        .background {
            TabBarItemIdentifiers(ids: AppTab.allCases.map { "tab.\($0.rawValue)" })
                .allowsHitTesting(false)
        }
        .onAppear {
            DiagnosticLines.line("route tab \(selectedTab.rawValue)")
        }
        .onChange(of: selectedTab) { _, tab in
            // A finger tap is `tap tab.<id>` from the touch hook, including a retap of the
            // current tab. This line is only the route for a programmatic change.
            DiagnosticTaps.logSelectionChange(tab.rawValue)
        }
    }

    @ViewBuilder
    private func tabLabel(for tab: AppTab) -> some View {
        (selectedTab == tab ? tab.selectedIcon : tab.unselectedIcon).image
        Text(DesignSystemLocalizedString.string(tab.titleKey, locale: locale))
    }
}

/// Writes `tab.home` on each `UITabBarItem`. SwiftUI's tab label does not land on the
/// button the finger hits, and iOS 27's platter is not a `UITabBar` subview of that hit.
private struct TabBarItemIdentifiers: UIViewRepresentable {
    var ids: [String]

    func makeUIView(context: Context) -> TabBarItemIdentifierView {
        TabBarItemIdentifierView()
    }

    func updateUIView(_ view: TabBarItemIdentifierView, context: Context) {
        view.ids = ids
        view.apply()
    }
}

private final class TabBarItemIdentifierView: UIView {
    var ids: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        apply()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        apply()
    }

    func apply() {
        guard let window, let bar = Self.tabBar(in: window) else { return }
        let items = bar.items ?? []
        guard items.count == ids.count else { return }
        for (item, id) in zip(items, ids) where item.accessibilityIdentifier != id {
            item.accessibilityIdentifier = id
        }
    }

    private static func tabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar, bar.items?.isEmpty == false { return bar }
        for subview in view.subviews {
            if let bar = tabBar(in: subview) { return bar }
        }
        return nil
    }
}
