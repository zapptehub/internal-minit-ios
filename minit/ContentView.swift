//
//  ContentView.swift
//  minit
//
//  Created by Armands Berzins on 29/06/2026.
//

import SwiftUI
import DesignSystem
import FeatureLogin
import FeatureStart

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
    @State private var isAuthenticated = false
    @State private var activeSheet: AuthSheet?
    /// Set right before dismissing the login sheet on password-reset success; consumed in
    /// `onDismiss` once that sheet has fully gone, to present the Password Changed sheet.
    @State private var pendingPasswordChanged = false

    var body: some View {
        if isAuthenticated {
            Text("Welcome!")
        } else {
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
                        onLoginSuccess: { _ in
                            activeSheet = nil
                            isAuthenticated = true
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
    }
}
