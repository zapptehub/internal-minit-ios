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
    @Environment(\.locale) private var locale

    /// Figma spec — gap between adjacent `DSInputField`s on this screen.
    private let fieldSpacing: CGFloat = 24

    /// Figma spec — larger gap between the subtitle block and the first input field than the
    /// spacing used between the fields themselves or the other content sections below.
    private let headlineToFieldsSpacing: CGFloat = DSConstant.xxLarge.value

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text(LoginLocalizedString.string("createAccount.headline", locale: locale))
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.heading)
                    .accessibilityAddTraits(.isHeader)

                Text(LoginLocalizedString.string("createAccount.subtitle", locale: locale))
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.secondary)
            }

            VStack(spacing: fieldSpacing) {
                DSInputField(
                    label: LoginLocalizedString.string("createAccount.field.email", locale: locale),
                    text: $viewModel.email,
                    validationState: viewModel.hasEmailFormatError ? .error : .none,
                    isEnabled: true,
                    keyboardTypeOverride: .emailAddress
                )
                DSInputField(
                    label: LoginLocalizedString.string("login.field.password", locale: locale),
                    text: $viewModel.password,
                    type: .password,
                    placeholder: LoginLocalizedString.string("createAccount.field.placeholder", locale: locale),
                    validationState: viewModel.hasPasswordLengthError ? .error : .none
                )
                DSInputField(
                    label: LoginLocalizedString.string("createAccount.field.confirmPassword", locale: locale),
                    text: $viewModel.confirmPassword,
                    type: .password,
                    placeholder: LoginLocalizedString.string("createAccount.field.placeholder", locale: locale),
                    validationState: passwordsMismatch ? .error : .none
                )
            }
            .padding(.top, headlineToFieldsSpacing)

            DSCheckbox(
                label: LoginLocalizedString.string("createAccount.checkbox.marketingOptIn", locale: locale),
                isChecked: $viewModel.marketingOptIn
            )
            .padding(.top, DSConstant.large.value)

            if let errorMessage = viewModel.errorMessage {
                DSWarningMessage(message: errorMessage)
                    .padding(.top, DSConstant.large.value)
            }

            VStack(spacing: DSConstant.mediumLarge.value) {
                DSButton(
                    title: LoginLocalizedString.string("createAccount.button.continue", locale: locale),
                    type: .primary,
                    isEnabled: isContinueEnabled,
                    isLoading: viewModel.state.isLoading
                ) {
                    analytics.trackSignUpAttempt(file: #fileID)
                    viewModel.submitCreateAccount()
                }

                HStack(spacing: DSConstant.small.value) {
                    DSButton(
                        title: LoginLocalizedString.string("login.button.apple", locale: locale),
                        type: .social,
                        icon: .appleLogo,
                        heightStyle: .large
                    ) {
                        analytics.trackAppleSignInTapped(file: #fileID)
                        viewModel.signInWithApple()
                    }
                    DSButton(
                        title: LoginLocalizedString.string("login.button.google", locale: locale),
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
    /// passwords, and the marketing checkbox checked. Also requires `LoginViewModel
    /// .minimumPasswordLength` so a too-short password is caught here rather than surfacing
    /// as a server-side error once the user reaches the Verification Code step.
    private var isContinueEnabled: Bool {
        viewModel.isEmailValid
            && viewModel.password.count >= LoginViewModel.minimumPasswordLength
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
