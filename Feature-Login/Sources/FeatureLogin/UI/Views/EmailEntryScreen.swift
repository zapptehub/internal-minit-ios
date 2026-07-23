import SwiftUI
import DesignSystem
import DataAuth

/// Root step of the auth flow — collects an email address and routes to Create Account or
/// Welcome Back via `LoginViewModel.continueFromEmail()`, which looks up whether it belongs to
/// an existing account. Pushed by `LoginScreen`'s `NavigationStack`; the shared
/// `AuthFlowNavigationBar` (logo) lives there, not here — this screen only owns the content
/// that's specific to this step (headline, subtitle, field, buttons).
struct EmailEntryScreen: View {
    @Bindable var viewModel: LoginViewModel
    let analytics: LoginAnalyticsTracking
    @FocusState private var isEmailFieldFocused: Bool

    /// Figma spec (node `6161:2128`) — the email field's oversized placeholder-style
    /// text. Ad hoc value, not a reusable `DSConstant`, same precedent as `StartScreen`'s
    /// `topOffset`.
    private let emailFieldFontSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.large.value) {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text(String(localized: "login.headline", bundle: .module))
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.heading)
                    .tracking(-1)

                Text(String(localized: "login.subtitle", bundle: .module))
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.secondary)
            }

            TextField(
                String(localized: "login.field.email", bundle: .module),
                text: $viewModel.email
            )
            .font(.system(size: emailFieldFontSize))
            .foregroundColor(DSColor.Text.primary)
            .tint(DSColor.Text.primary)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .textContentType(.emailAddress)
            .focused($isEmailFieldFocused)

            if let errorMessage = viewModel.errorMessage {
                DSWarningMessage(message: errorMessage)
            }

            VStack(spacing: DSConstant.mediumLarge.value) {
                DSButton(
                    title: String(localized: "login.button.login", bundle: .module),
                    type: .primary,
                    isEnabled: viewModel.isEmailValid && !viewModel.state.isLoading,
                    isLoading: viewModel.state.isLoading
                ) {
                    analytics.trackEmailContinueTapped(file: #fileID)
                    viewModel.continueFromEmail()
                }

                HStack(spacing: DSConstant.small.value) {
                    DSButton(
                        title: String(localized: "login.button.apple", bundle: .module),
                        type: .social,
                        icon: .appleLogo,
                        heightStyle: .large
                    ) {
                        analytics.trackAppleSignInTapped(file: #fileID)
                        viewModel.signInWithApple()
                    }
                    DSButton(
                        title: String(localized: "login.button.google", bundle: .module),
                        type: .social,
                        icon: .google,
                        heightStyle: .large
                    ) {
                        analytics.trackGoogleSignInTapped(file: #fileID)
                        viewModel.signInWithGoogle()
                    }
                }
            }

            Spacer()
        }
        .authFlowStepContent()
        .onAppear {
            isEmailFieldFocused = true
        }
    }
}

#Preview {
    NavigationStack {
        EmailEntryScreen(
            viewModel: LoginViewModel(authRepository: PreviewAuthRepository()),
            analytics: PreviewLoginAnalyticsTracking()
        )
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }
}
