import SwiftUI
import DesignSystem
import DataAuth

/// Root of the multi-step auth flow. Hosts the one piece of UI that's constant across every
/// step (`AuthFlowNavigationBar`) above a `NavigationStack` whose own system nav bar stays
/// hidden; each pushed screen supplies its own headline/subtitle/content below the logo. See
/// `plans/ios-auth-flow-multi-step.md`.
struct LoginScreen: View {
    @State private var viewModel: LoginViewModel
    let analytics: LoginAnalyticsTracking

    init(viewModel: LoginViewModel, analytics: LoginAnalyticsTracking) {
        self._viewModel = State(initialValue: viewModel)
        self.analytics = analytics
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.large.value) {
            AuthFlowNavigationBar()
                .padding(.horizontal, AuthFlowStepLayout.horizontalInset)

            NavigationStack(path: $viewModel.path) {
                EmailEntryScreen(viewModel: viewModel, analytics: analytics)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: AuthFlowRoute.self) { route in
                        destination(for: route)
                            .toolbar(.hidden, for: .navigationBar)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.top, AuthFlowNavigationBar.topPadding)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
        .featureUnderConstructionAlert(isPresented: $viewModel.showsFeatureUnderConstructionAlert)
    }

    /// Built out incrementally — each case gets its real screen as that step lands (see the
    /// remaining steps in `plans/ios-auth-flow-multi-step.md`). `EmptyView` keeps this
    /// exhaustive switch compiling today without blocking on screens that don't exist yet.
    @ViewBuilder
    private func destination(for route: AuthFlowRoute) -> some View {
        switch route {
        case .createAccount:
            CreateAccountScreen(viewModel: viewModel, analytics: analytics)
        case .welcomeBack:
            WelcomeBackScreen(viewModel: viewModel, analytics: analytics)
        case .verificationCode(let purpose):
            VerificationCodeScreen(viewModel: viewModel, analytics: analytics, purpose: purpose)
        case .forgotPasswordEmail:
            ForgotPasswordEmailScreen(viewModel: viewModel, analytics: analytics)
        }
    }
}

#Preview {
    LoginScreen(
        viewModel: LoginViewModel(authRepository: PreviewAuthRepository()),
        analytics: PreviewLoginAnalyticsTracking()
    )
}
