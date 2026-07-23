import SwiftUI
import DesignSystem
import DataAuth

/// Pushed from `EmailEntryScreen` when `continueFromEmail()` determines `email` doesn't belong
/// to an existing account (`.createAccount` route). Collects a password + confirmation and a
/// marketing opt-in, then hands off to the shared Verification Code step via
/// `LoginViewModel.submitCreateAccount()`. See `plans/ios-auth-flow-multi-step.md`.
struct CreateAccountScreen: View {
    @Bindable var viewModel: LoginViewModel
    let analytics: LoginAnalyticsTracking

    /// Figma spec — gap between adjacent `DSInputField`s on this screen.
    private let fieldSpacing: CGFloat = 24

    /// Figma spec — larger gap between the subtitle block and the first input field than the
    /// spacing used between the fields themselves or the other content sections below.
    private let headlineToFieldsSpacing: CGFloat = DSConstant.xxLarge.value

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text(String(localized: "createAccount.headline", bundle: .module))
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.heading)
                    .tracking(-1)

                Text(String(localized: "createAccount.subtitle", bundle: .module))
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.secondary)
            }

            VStack(spacing: fieldSpacing) {
                DSInputField(
                    label: String(localized: "createAccount.field.email", bundle: .module),
                    text: $viewModel.email,
                    validationState: viewModel.hasEmailFormatError ? .error : .none,
                    isEnabled: true,
                    keyboardTypeOverride: .emailAddress
                )
                DSInputField(
                    label: String(localized: "login.field.password", bundle: .module),
                    text: $viewModel.password,
                    type: .password,
                    placeholder: String(localized: "createAccount.field.placeholder", bundle: .module)
                )
                DSInputField(
                    label: String(localized: "createAccount.field.confirmPassword", bundle: .module),
                    text: $viewModel.confirmPassword,
                    type: .password,
                    placeholder: String(localized: "createAccount.field.placeholder", bundle: .module),
                    validationState: passwordsMismatch ? .error : .none
                )
            }
            .padding(.top, headlineToFieldsSpacing)

            DSCheckbox(
                label: String(localized: "createAccount.checkbox.marketingOptIn", bundle: .module),
                isChecked: $viewModel.marketingOptIn
            )
            .padding(.top, DSConstant.large.value)

            if let errorMessage = viewModel.errorMessage {
                DSWarningMessage(message: errorMessage)
                    .padding(.top, DSConstant.large.value)
            }

            VStack(spacing: DSConstant.mediumLarge.value) {
                DSButton(
                    title: String(localized: "createAccount.button.continue", bundle: .module),
                    type: .primary,
                    isEnabled: isContinueEnabled,
                    isLoading: viewModel.state.isLoading
                ) {
                    analytics.trackSignUpAttempt(file: #fileID)
                    viewModel.submitCreateAccount()
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
            .padding(.top, DSConstant.large.value)

            Spacer()
        }
        .authFlowStepContent()
    }

    private var passwordsMismatch: Bool {
        !viewModel.confirmPassword.isEmpty && viewModel.confirmPassword != viewModel.password
    }

    /// Matches the plan's "disabled/enabled screenshots" spec exactly: non-empty, matching
    /// passwords, and the marketing checkbox checked.
    private var isContinueEnabled: Bool {
        viewModel.isEmailValid
            && !viewModel.password.isEmpty
            && viewModel.password == viewModel.confirmPassword
            && viewModel.marketingOptIn
            && !viewModel.state.isLoading
    }
}

#Preview {
    NavigationStack {
        CreateAccountScreen(
            viewModel: {
                let vm = LoginViewModel(authRepository: PreviewAuthRepository())
                vm.email = "new@minit.com"
                return vm
            }(),
            analytics: PreviewLoginAnalyticsTracking()
        )
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }
}
