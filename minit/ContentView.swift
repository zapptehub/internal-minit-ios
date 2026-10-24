//
//  ContentView.swift
//  minit
//
//  Created by Armands Berzins on 29/06/2026.
//

import SwiftUI
import DesignSystem
import CoreExtensions
import CoreNetworking
import FeatureHome
import FeatureLogin
import FeatureStart
import FeatureOnboarding
import FeatureTabRoot

/// Which of the two sequential, mutually-exclusive sheets is on screen. Using a single
/// `.sheet(item:)` bound to this — rather than two stacked `.sheet(isPresented:)` modifiers
/// on the same view — is the reliable way to sequence a dismiss-then-present handoff in
/// SwiftUI; two `.sheet(isPresented:)` on one view can silently fail to present the second
/// sheet when triggered from the first sheet's own dismissal. See
/// `plans/password_changed_second_sheet_9f2e404f.plan.md`.
private enum AuthSheet: Identifiable {
    case login
    case passwordChanged

    var id: Self { self }
}

struct ContentView: View {
    @State private var appFlow = AppFlowViewModel(
        authRepository: AppDependencies.shared.authRepository,
        loyaltyCardRepository: AppDependencies.shared.loyaltyCardRepository,
        onboardingProgressStore: AppDependencies.shared.onboardingProgressStore,
        networkClient: AppDependencies.shared.networkClient,
        demoSessionStore: AppDependencies.shared.authDataModule.demoSessionStore,
        clearAvatarURLCache: {
            AppDependencies.shared.networkClient.clearCachedResponses()
        }
    )
    @State private var activeSheet: AuthSheet?
    /// Set right before dismissing the login sheet on password-reset success; consumed in
    /// `onDismiss` once that sheet has fully gone, to present the Password Changed sheet.
    @State private var pendingPasswordChanged = false
    /// Device-wide language choice (see `AppLanguagePreferenceStoring`) — `@AppStorage`
    /// (rather than reading `AppDependencies.shared.appLanguagePreference` once) so this
    /// view re-renders immediately when `OnboardingViewModel.continueFromLanguage()`
    /// writes a new value, without any direct coupling between the two. Empty string is
    /// the "never explicitly set yet" sentinel — `@AppStorage` can't hold `String?`.
    @AppStorage(UserDefaultsAppLanguagePreferenceStore.defaultKey) private var appLanguageCode = ""

    var body: some View {
        content
            .environment(\.locale, currentLocale)
            .task {
                await appFlow.bootstrap()
            }
    }

    /// A confirmed device-wide language choice applies everywhere — Start, Login, the
    /// whole onboarding flow, and post-onboarding screens alike — and survives logout,
    /// since it's stored independently of any account. Only falls back to whatever
    /// language a resuming *mid-onboarding* checkpoint carries (see
    /// `AppFlowViewModel.restoredLocale`'s doc comment), and then to the system default,
    /// when nothing has been explicitly confirmed yet.
    private var currentLocale: Locale {
        if !appLanguageCode.isEmpty {
            return Locale(identifier: appLanguageCode)
        }
        return appFlow.restoredLocale ?? .autoupdatingCurrent
    }

    @ViewBuilder
    private var content: some View {
        switch appFlow.state {
        case .loading:
            loadingView
        case .sessionRestoreFailed, .onboardingStatusFailed:
            LaunchFailedView(state: appFlow.state) {
                appFlow.retryBootstrap()
            }
        case .unauthenticated:
            unauthenticatedFlow
        case .onboarding(let userId):
            onboardingFlow(userId: userId)
        case .authenticated(let userId):
            FeatureTabRoot.createScreen(
                userId: userId,
                profileRepository: AppDependencies.shared.profileRepository,
                homeRepository: AppDependencies.shared.homeRepository,
                networkClient: AppDependencies.shared.networkClient,
                apiBaseURL: AppDependencies.shared.apiBaseURL,
                onLogOut: appFlow.logOut
            )
        }
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }

    private var unauthenticatedFlow: some View {
        FeatureStart.createScreen(
            analytics: AppDependencies.shared.startAnalytics,
            showsDemo: AppDependencies.shared.showsDemo,
            onGetStarted: {
                // A prior demo attempt must not outlive an email login that follows it.
                appFlow.clearDemoSession()
                activeSheet = .login
            },
            onDemoContinue: {
                appFlow.startDemo()
            }
        )
        .alert(
            AppLocalizedString.string("appFlow.demoStart.error.title", locale: currentLocale),
            isPresented: demoStartErrorPresented
        ) {
            Button(DesignSystemLocalizedString.string("common.alert.ok", locale: currentLocale)) {
                appFlow.clearDemoStartError()
            }
        } message: {
            Text(AppLocalizedString.string("appFlow.demoStart.error.message", locale: currentLocale))
        }
        .sheet(item: $activeSheet, onDismiss: {
            if pendingPasswordChanged {
                pendingPasswordChanged = false
                DispatchQueue.main.async {
                    activeSheet = .passwordChanged
                }
            }
        }) { sheet in
            switch sheet {
            case .login:
                FeatureLogin.createScreen(
                    authRepository: AppDependencies.shared.authRepository,
                    analytics: AppDependencies.shared.loginAnalytics,
                    onLoginSuccess: { authData in
                        activeSheet = nil
                        appFlow.didLogIn(authData)
                    },
                    onPasswordResetCompleted: {
                        pendingPasswordChanged = true
                        activeSheet = nil
                    }
                )
                .presentationDragIndicator(.visible)
            case .passwordChanged:
                FeatureLogin.createPasswordChangedScreen(
                    analytics: AppDependencies.shared.loginAnalytics
                ) {
                    activeSheet = nil
                }
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var demoStartErrorPresented: Binding<Bool> {
        Binding(
            get: { appFlow.demoStartErrorMessage != nil },
            set: { isPresented in
                if !isPresented { appFlow.clearDemoStartError() }
            }
        )
    }

    private func onboardingFlow(userId: String) -> some View {
        FeatureOnboarding.createScreen(
            userId: userId,
            profileRepository: AppDependencies.shared.profileRepository,
            loyaltyCardRepository: AppDependencies.shared.loyaltyCardRepository,
            progressStore: AppDependencies.shared.onboardingProgressStore,
            appLanguagePreference: AppDependencies.shared.appLanguagePreference,
            analytics: AppDependencies.shared.onboardingAnalytics,
            onCompleted: {
                appFlow.didCompleteOnboarding(userId: userId)
            }
        )
    }
}

/// Session-restore failure and onboarding-status failure each show their own
/// catalog title and message. Reads the locale `ContentView` publishes, which
/// is the in-app language when one has been confirmed.
struct LaunchFailedView: View {
    let state: AppFlowViewModel.State
    var announce: (String, String) -> Void
    let onRetry: () -> Void
    @Environment(\.locale) private var locale

    init(
        state: AppFlowViewModel.State,
        announce: @escaping (String, String) -> Void = { title, message in
            LaunchFailureAnnouncement.post(title: title, message: message)
        },
        onRetry: @escaping () -> Void
    ) {
        self.state = state
        self.announce = announce
        self.onRetry = onRetry
    }

    var body: some View {
        if let copy = LaunchFailureCopy(state: state, locale: locale) {
            VStack(spacing: DSConstant.medium.value) {
                LaunchFailureStatusIcon()
                Text(copy.title)
                    .typography(.headingMediumBold)
                    .foregroundColor(DSColor.Text.heading)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(copy.message)
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.secondary)
                    .multilineTextAlignment(.center)
                DSButton(title: copy.retry, type: .tertiary) {
                    onRetry()
                }
            }
            .padding(DSConstant.large.value)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.Background.Layer.level0.ignoresSafeArea())
            .onAppear {
                announce(copy.title, copy.message)
            }
        }
    }
}

/// Warning glyph matching Android's launch-failure icon: a 48 pt circle
/// (`DsSize.MinimumTouchTarget`) and a 24 pt triangle (`DsSize.IconLarge`),
/// error-tinted on the level-one surface. Decorative — the title and message
/// carry the meaning, and an assertive announcement speaks them on appear.
private struct LaunchFailureStatusIcon: View {
    /// Android `DsSize.MinimumTouchTarget` / scale 1200.
    private static let diameter: CGFloat = 48
    /// Android `DsSize.IconLarge` / scale 600.
    private static let glyphSize = DSConstant.large.value

    var body: some View {
        ZStack {
            Circle()
                .fill(DSColor.Background.Layer.level1)
                .frame(width: Self.diameter, height: Self.diameter)
            DSIconView(
                icon: .warningTriangle,
                size: Self.glyphSize,
                color: DSColor.Border.error
            )
        }
        .accessibilityHidden(true)
    }
}

/// Assertive VoiceOver announcement for the launch-failure screen, matching
/// Android's `LiveRegionMode.Assertive` on the retry column.
enum LaunchFailureAnnouncement {
    static func spoken(title: String, message: String) -> String {
        "\(title). \(message)"
    }

    static func attributed(title: String, message: String) -> AttributedString {
        var announcement = AttributedString(spoken(title: title, message: message))
        announcement.accessibilitySpeechAnnouncementPriority = .high
        return announcement
    }

    static func post(title: String, message: String) {
        AccessibilityNotification.Announcement(attributed(title: title, message: message)).post()
    }
}
