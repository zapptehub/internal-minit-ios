import SwiftUI
import DesignSystem
import DataAuth

/// Pushed from `WelcomeBackScreen` when the user taps "Forgot Password?" (`.forgotPasswordEmail`
/// route). Confirms the account email, then hands off to the shared Verification Code step via
/// `LoginViewModel.submitForgotPasswordEmail()`. See `plans/ios-auth-flow-multi-step.md`.
struct ForgotPasswordEmailScreen: View {
    @Bindable var viewModel: LoginViewModel
    let analytics: LoginAnalyticsTracking

    private let headlineToFieldsSpacing: CGFloat = DSConstant.xxLarge.value

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text(String(localized: "forgotPassword.headline", bundle: .module))
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.heading)
                    .tracking(-1)

                Text(String(localized: "forgotPassword.subtitle", bundle: .module))
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.secondary)
            }

            DSInputField(
                label: String(localized: "createAccount.field.email", bundle: .module),
                text: $viewModel.email,
                validationState: viewModel.hasEmailFormatError ? .error : .none,
                keyboardTypeOverride: .emailAddress
            )
            .padding(.top, headlineToFieldsSpacing)

            contactSupportLink
                .padding(.top, DSConstant.large.value)

            if let errorMessage = viewModel.errorMessage {
                DSWarningMessage(message: errorMessage)
                    .padding(.top, DSConstant.large.value)
            }

            DSButton(
                title: String(localized: "forgotPassword.button.resetPassword", bundle: .module),
                type: .tertiary,
                isEnabled: isResetEnabled,
                isLoading: viewModel.state.isLoading
            ) {
                analytics.trackForgotPasswordRequested(file: #fileID)
                viewModel.submitForgotPasswordEmail()
            }
            .padding(.top, DSConstant.xxLarge.value)

            Spacer()
        }
        .authFlowStepContent()
    }

    private var isResetEnabled: Bool {
        viewModel.isEmailValid && !viewModel.state.isLoading
    }

    /// Stub — shows the shared "under construction" alert via `LoginViewModel`.
    private var contactSupportLink: some View {
        Button {
            viewModel.showFeatureUnderConstruction()
        } label: {
            HStack(spacing: DSConstant.small.value) {
                Text(String(localized: "forgotPassword.link.contactSupport", bundle: .module))
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.link)
                    .underline()

                DSIconView(icon: .externalLink, size: 10, color: DSColor.Text.link)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordEmailScreen(
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
