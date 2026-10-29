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
    @Environment(\.locale) private var locale
    @FocusState private var isEmailFieldFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Figma spec (node `6161:2128`) — the email field's oversized placeholder-style
    /// text. Ad hoc value, not a reusable `DSConstant`, same precedent as `StartScreen`'s
    /// `topOffset`. `@ScaledMetric` keeps 30pt at the default content size and
    /// scales with the body text style afterwards, with no cap.
    @ScaledMetric(relativeTo: .body) private var emailFieldFontSize: CGFloat = 30

    var body: some View {
        AuthFlowLargeLayout {
            VStack(alignment: .leading, spacing: DSConstant.large.value) {
                VStack(alignment: .leading, spacing: DSConstant.small.value) {
                    DSGrowingText(
                        text: LoginLocalizedString.string("login.headline", locale: locale),
                        type: .headingLargeSemibold,
                        color: DSColor.Text.heading
                    )
                    .accessibilityAddTraits(.isHeader)

                    Text(LoginLocalizedString.string("login.subtitle", locale: locale))
                        .typography(.paragraphRegular)
                        .foregroundColor(DSColor.Text.secondary)
                        .uncompressedWhenTextIsLarge()
                }

                emailField
                    .font(.system(size: emailFieldFontSize))
                    .foregroundColor(DSColor.Text.primary)
                    .tint(DSColor.Text.primary)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .focused($isEmailFieldFocused)
                    .diagnosticField(id: "email", text: viewModel.email, isFocused: isEmailFieldFocused)
                    .frame(minHeight: dynamicTypeSize > .large ? emailFieldFontSize * 1.25 : nil, alignment: .leading)
                    .accessibilityLabel(LoginLocalizedString.string("createAccount.field.email", locale: locale))
                    .accessibilityHintIfPresent(invalidEmailAccessibilityHint)

                if let errorMessage = viewModel.errorMessage {
                    DSWarningMessage(message: errorMessage)
                }
            }
        } actions: {
            VStack(spacing: DSConstant.mediumLarge.value) {
                DSButton(
                    title: LoginLocalizedString.string("login.button.login", locale: locale),
                    type: .primary,
                    isEnabled: viewModel.isEmailValid && !viewModel.state.isLoading,
                    isLoading: viewModel.state.isLoading
                ) {
                    analytics.trackEmailContinueTapped(file: #fileID)
                    viewModel.continueFromEmail()
                }

                socialButtons
            }
        }
        .authFlowStepContent()
        .onAppear {
            isEmailFieldFocused = true
        }
    }

    /// Side by side at the default content size. Above that each label is wider
    /// than half the row, so the pills stack and the words stay intact.
    @ViewBuilder
    private var socialButtons: some View {
        if dynamicTypeSize > .large {
            VStack(spacing: DSConstant.small.value) {
                appleButton
                googleButton
            }
        } else {
            HStack(spacing: DSConstant.small.value) {
                appleButton
                googleButton
            }
        }
    }

    private var appleButton: some View {
        DSButton(
            title: LoginLocalizedString.string("login.button.apple", locale: locale),
            type: .social,
            icon: .appleLogo,
            heightStyle: .large
        ) {
            analytics.trackAppleSignInTapped(file: #fileID)
            viewModel.signInWithApple()
        }
    }

    private var googleButton: some View {
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

    /// One line at the default content size. Above that, the address wraps inside
    /// the field instead of ending in an ellipsis.
    @ViewBuilder
    private var emailField: some View {
        if dynamicTypeSize > .large {
            // The system placeholder is one line and draws an ellipsis once 30pt
            // scaled past the field width. A wrapping stand-in shows the whole address.
            ZStack(alignment: .topLeading) {
                if viewModel.email.isEmpty {
                    Text(wrappingEmailPlaceholder)
                        .foregroundStyle(Color(uiColor: .placeholderText))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
                // One line, like Android's email field: a long address scrolls
                // inside the field instead of growing over the buttons.
                TextField("", text: $viewModel.email)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            TextField(
                LoginLocalizedString.string("login.field.email", locale: locale),
                text: $viewModel.email
            )
        }
    }

    /// Break after `@` and `.` so the sample address wraps on those marks
    /// instead of splitting a word in the middle.
    private var wrappingEmailPlaceholder: String {
        LoginLocalizedString.string("login.field.email", locale: locale)
            .replacingOccurrences(of: "@", with: "@\u{200B}")
            .replacingOccurrences(of: ".", with: ".\u{200B}")
    }

    /// `common.a11y.inputError` when Continue is disabled because the address is invalid.
    private var invalidEmailAccessibilityHint: String? {
        guard viewModel.hasEmailFormatError else { return nil }
        return DesignSystemLocalizedString.string("common.a11y.inputError", locale: locale)
    }
}

private extension View {
    @ViewBuilder
    func accessibilityHintIfPresent(_ hint: String?) -> some View {
        if let hint, !hint.isEmpty {
            accessibilityHint(hint)
        } else {
            self
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
