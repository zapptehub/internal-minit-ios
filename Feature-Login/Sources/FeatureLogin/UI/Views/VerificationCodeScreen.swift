import SwiftUI
import DesignSystem
import DataAuth

/// Shared OTP step for sign-up, sign-in, and password-reset flows. Arrives via
/// `.verificationCode(VerificationPurpose)` after `submitCreateAccount()`, `submitSignIn()`,
/// or (later) `submitForgotPasswordEmail()`. See `plans/ios-auth-flow-multi-step.md`.
struct VerificationCodeScreen: View {
    @Bindable var viewModel: LoginViewModel
    let analytics: LoginAnalyticsTracking
    let purpose: VerificationPurpose
    @Environment(\.locale) private var locale

    /// Set when the user taps Confirm; cleared after async outcome is tracked so resend
    /// failures don't fire sign-in/sign-up failure events.
    @State private var confirmInFlight = false

    private let headlineToContentSpacing: CGFloat = DSConstant.xxLarge.value

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text(LoginLocalizedString.string("verification.headline", locale: locale))
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.heading)

                subtitle
            }

            DSOTPField(
                label: LoginLocalizedString.string("verification.field.otp", locale: locale),
                code: $viewModel.otpCode
            )
            .padding(.top, headlineToContentSpacing)

            resendRow
                .padding(.top, DSConstant.large.value)

            if let errorMessage = viewModel.errorMessage {
                DSWarningMessage(message: errorMessage)
                    .padding(.top, DSConstant.large.value)
            }

            DSButton(
                title: confirmButtonTitle,
                type: .tertiary,
                isEnabled: isConfirmEnabled,
                isLoading: viewModel.state.isLoading
            ) {
                confirmInFlight = true
                viewModel.confirmVerification(purpose: purpose)
            }
            .padding(.top, DSConstant.large.value)

            if showsSupportFooter {
                supportFooter
                    .padding(.top, DSConstant.large.value)
            }

            Spacer()
        }
        .authFlowStepContent()
        .onAppear {
            viewModel.onVerificationScreenAppeared()
        }
        .onChange(of: viewModel.state) { _, newState in
            guard confirmInFlight else { return }
            switch newState {
            case .authenticated:
                confirmInFlight = false
                switch purpose {
                case .signIn:
                    analytics.trackLoginSuccess(file: #fileID)
                case .signUp:
                    analytics.trackSignUpSuccess(file: #fileID)
                case .passwordReset:
                    break
                }
            case .idle where purpose == .passwordReset:
                confirmInFlight = false
            case .error(let message):
                confirmInFlight = false
                switch purpose {
                case .signIn:
                    analytics.trackLoginFailed(reason: message, file: #fileID)
                case .signUp:
                    analytics.trackSignUpFailed(reason: message, file: #fileID)
                case .passwordReset:
                    break
                }
            default:
                break
            }
        }
        .onChange(of: viewModel.passwordResetCompleted) { _, completed in
            if completed, purpose == .passwordReset {
                analytics.trackPasswordResetCompleted(file: #fileID)
            }
        }
    }

    private var subtitle: some View {
        (
            Text(LoginLocalizedString.string("verification.subtitle.prefix", locale: locale))
                .foregroundColor(DSColor.Text.secondary)
            + Text(viewModel.email)
                .foregroundColor(DSColor.Text.accent)
                .underline()
        )
        .typography(.paragraphRegular)
        .lineSpacing(DSConstant.small.value)
    }

    private var resendRow: some View {
        HStack(spacing: DSConstant.mediumLarge.value) {
            Text(viewModel.resendCountdownFormatted)
                .typography(.uiLargeBold)
                .foregroundColor(DSColor.Text.heading)
                .monospacedDigit()

            sendAgainButton
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var sendAgainButton: some View {
        DSButton(
            title: LoginLocalizedString.string("verification.link.sendAgain", locale: locale),
            type: .tertiary,
            isEnabled: isSendAgainEnabled,
            heightStyle: .small,
            widthStyle: .compact
        ) {
            analytics.trackVerificationCodeResent(file: #fileID)
            viewModel.resendCode()
        }
    }

    private var isSendAgainEnabled: Bool {
        viewModel.canResendCode && !viewModel.state.isLoading
    }

    private var supportFooter: some View {
        Button {
            viewModel.showFeatureUnderConstruction()
        } label: {
            (
                Text(LoginLocalizedString.string("verification.link.support.prefix", locale: locale))
                    .foregroundColor(DSColor.Text.secondary)
                + Text(LoginLocalizedString.string("verification.link.support.action", locale: locale))
                    .foregroundColor(DSColor.Text.primary)
                    .underline()
            )
            .typography(.uiRegular)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var confirmButtonTitle: String {
        switch purpose {
        case .signUp, .signIn:
            LoginLocalizedString.string("verification.button.confirmSignIn", locale: locale)
        case .passwordReset:
            LoginLocalizedString.string("verification.button.confirmPasswordChange", locale: locale)
        }
    }

    private var showsSupportFooter: Bool {
        purpose == .signUp || purpose == .signIn
    }

    private var isConfirmEnabled: Bool {
        viewModel.otpCode.count == 4 && !viewModel.state.isLoading
    }
}

#Preview("Verification — sign in") {
    NavigationStack {
        VerificationCodeScreen(
            viewModel: {
                let vm = LoginViewModel(authRepository: PreviewAuthRepository())
                vm.email = "iveta@minitbakery.com"
                vm.resendCountdownSeconds = 104
                return vm
            }(),
            analytics: PreviewLoginAnalyticsTracking(),
            purpose: .signIn
        )
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }
}

#Preview("Verification — resend enabled") {
    NavigationStack {
        VerificationCodeScreen(
            viewModel: {
                let vm = LoginViewModel(authRepository: PreviewAuthRepository())
                vm.email = "iveta@minitbakery.com"
                vm.resendCountdownSeconds = 0
                return vm
            }(),
            analytics: PreviewLoginAnalyticsTracking(),
            purpose: .signIn
        )
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }
}
