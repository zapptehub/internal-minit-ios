//
//  ContentView.swift
//  minit
//
//  Created by Armands Berzins on 29/06/2026.
//

import SwiftUI
import DesignSystem
import CoreExtensions
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
        onboardingProgressStore: AppDependencies.shared.onboardingProgressStore
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
            launchFailedView
        case .unauthenticated:
            unauthenticatedFlow
        case .onboarding(let userId):
            onboardingFlow(userId: userId)
        case .authenticated:
            FeatureTabRoot.createScreen(onLogOut: appFlow.logOut)
        }
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }

    /// Covers both `.sessionRestoreFailed` (couldn't tell if signed in) and
    /// `.onboardingStatusFailed` (signed in, but couldn't tell if a card is linked).
    /// No mockup exists; kept DS-consistent and minimal.
    private var launchFailedView: some View {
        VStack(spacing: DSConstant.medium.value) {
            Text("Something went wrong")
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)
            Text("We couldn't check your session. Check your connection and try again.")
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.secondary)
                .multilineTextAlignment(.center)
            DSButton(title: "Retry", type: .tertiary) {
                appFlow.retryBootstrap()
            }
        }
        .padding(DSConstant.large.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }

    private var unauthenticatedFlow: some View {
        FeatureStart.createScreen(
            analytics: AppDependencies.shared.startAnalytics
        ) {
            activeSheet = .login
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

    private func onboardingFlow(userId: String) -> some View {
        FeatureOnboarding.createScreen(
            userId: userId,
            profileRepository: AppDependencies.shared.profileRepository,
            loyaltyCardRepository: AppDependencies.shared.loyaltyCardRepository,
            progressStore: AppDependencies.shared.onboardingProgressStore,
            appLanguagePreference: AppDependencies.shared.appLanguagePreference,
            analytics: AppDependencies.shared.onboardingAnalytics,
            onCompleted: {
                appFlow.didCompleteOnboarding()
            }
        )
    }
}
