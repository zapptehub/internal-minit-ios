import SwiftUI
import DesignSystem
import DataAuth

/// Pushed from `EmailEntryScreen` when `continueFromEmail()` determines `email` belongs to an
/// existing account (`.welcomeBack` route). Collects a password, offers forgot-password, then
/// hands off to the shared Verification Code step via `LoginViewModel.submitSignIn()`. See
/// `plans/ios-auth-flow-multi-step.md`.
struct WelcomeBackScreen: View {
    @Bindable var viewModel: LoginViewModel
    let analytics: LoginAnalyticsTracking
    @Environment(\.locale) private var locale

    private let fieldSpacing: CGFloat = 24
    private let headlineToFieldsSpacing: CGFloat = DSConstant.xxLarge.value
    /// Figma — small gap between the password field's bottom edge and "Forgot Password?".
    private let passwordToForgotPasswordSpacing: CGFloat = DSConstant.mediumLarge.value
    /// Figma — larger gap between the link and the Sign In button than above the link.
    private let forgotPasswordToSignInSpacing: CGFloat = DSConstant.large.value

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headline

            VStack(spacing: fieldSpacing) {
                DSInputField(
                    label: LoginLocalizedString.string("createAccount.field.email", locale: locale),
                    text: $viewModel.email,
                    validationState: viewModel.hasEmailFormatError ? .error : .none,
                    keyboardTypeOverride: .emailAddress
                )
                DSInputField(
                    label: LoginLocalizedString.string("login.field.password", locale: locale),
                    text: $viewModel.password,
                    type: .password,
                    placeholder: LoginLocalizedString.string("createAccount.field.placeholder", locale: locale)
                )
            }
            .padding(.top, headlineToFieldsSpacing)

            forgotPasswordLink
                .padding(.top, passwordToForgotPasswordSpacing)

            if let errorMessage = viewModel.errorMessage {
                DSWarningMessage(message: errorMessage)
                    .padding(.top, DSConstant.large.value)
            }

            DSButton(
                title: LoginLocalizedString.string("welcomeBack.button.signIn", locale: locale),
                type: .primary,
                isEnabled: isSignInEnabled,
                isLoading: viewModel.state.isLoading
            ) {
                analytics.trackLoginAttempt(file: #fileID)
                viewModel.submitSignIn()
            }
            .padding(.top, forgotPasswordToSignInSpacing)

            Spacer()
        }
        .authFlowStepContent()
    }

    /// Plain text link — not `DSButton(.textStyle)` because that renders a 52pt-tall pill
    /// touch target with horizontal inset, which misaligns the label vs. Figma's tight,
    /// right-flush link sitting just below the password field.
    private var forgotPasswordLink: some View {
        Button {
            analytics.trackForgotPasswordLinkTapped(file: #fileID)
            viewModel.openForgotPassword()
        } label: {
            Text(LoginLocalizedString.string("welcomeBack.link.forgotPassword", locale: locale))
                .typography(.uiRegular)
                .foregroundColor(DSColor.Text.secondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var headline: some View {
        (
            Text(LoginLocalizedString.string("welcomeBack.headline.prefix", locale: locale))
                .foregroundColor(DSColor.Text.heading)
            + Text(viewModel.firstName)
                .foregroundColor(DSColor.Text.accent)
        )
        .typography(.headingLargeSemibold)
    }

    private var isSignInEnabled: Bool {
        viewModel.isEmailValid
            && !viewModel.password.isEmpty
            && !viewModel.state.isLoading
    }
}

#Preview {
    NavigationStack {
        WelcomeBackScreen(
            viewModel: {
                let vm = LoginViewModel(authRepository: PreviewAuthRepository())
                vm.email = "iveta@minitbakery.com"
                return vm
            }(),
            analytics: PreviewLoginAnalyticsTracking()
        )
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }
}
