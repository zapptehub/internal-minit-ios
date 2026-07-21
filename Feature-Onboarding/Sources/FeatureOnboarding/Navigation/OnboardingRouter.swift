/// The complete onboarding transition table — every "given step X, where does the
/// flow go next" decision from the Task 1.2 transition matrix
/// (`plans/ios-onboarding-flow_fc28f096.plan.md`) lives here, and only here. This is
/// the one file to open when auditing "what happens on back" or "what happens after
/// this action" for any step.
///
/// Deliberately stateless and dependency-free — no repositories, no persistence, no
/// analytics — so every transition is a pure function you can unit test with zero
/// mocks. `OnboardingViewModel` asks this type for the next step via `advance(via:)`.
///
/// Intentional exceptions that still assign `step` directly in the view model
/// (not routed through here): restoring a persisted checkpoint in `apply(persisted:)`,
/// corrupted-progress recovery to `.name`, and `complete(with:)`'s success-chrome
/// landing on `.creatingCard` when bootstrap short-circuits mid-flow.
struct OnboardingRouter {
    /// Every user- or system-driven action that can move the flow to a new step —
    /// roughly one case per matrix row's "Continue / advance" or "Back" column.
    enum Transition: Equatable {
        case back
        case nameConfirmed
        case languageConfirmed
        case loyaltyDecisionConfirmed(OnboardingLoyaltyBranch)
        case cameraPermissionGranted
        case manualCardEntryChosen
        case codeSubmittedForClaim
        case createCardFailureDismissed
        case claimCardFailureDismissed(OnboardingClaimFailureKind, source: OnboardingClaimSource?)
        case unresumableScanReviewFallback
    }

    /// Returns the destination for `transition` fired while on `step`, or `nil` if
    /// the transition is illegal from that step (wrong source, or no back affordance).
    /// Callers treat `nil` as a no-op.
    func nextStep(from step: OnboardingStep, on transition: Transition) -> OnboardingStep? {
        switch transition {
        case .back:
            return backDestination(from: step)

        case .nameConfirmed:
            guard step == .name else { return nil }
            return .language

        case .languageConfirmed:
            guard step == .language else { return nil }
            return .loyaltyDecision

        case .loyaltyDecisionConfirmed(let branch):
            guard step == .loyaltyDecision else { return nil }
            switch branch {
            case .newCustomer: return .creatingCard
            case .existingCard: return .scannerPermission
            }

        case .cameraPermissionGranted:
            guard step == .scannerPermission else { return nil }
            return .scanning

        case .manualCardEntryChosen:
            // Allowed from the permission step (denied alert) or while already on
            // scanning if the screen offers a manual fallback without going back.
            guard step == .scannerPermission || step == .scanning else { return nil }
            return .manualCardEntry

        case .codeSubmittedForClaim:
            guard step == .scanning || step == .manualCardEntry else { return nil }
            return .scanReview

        case .createCardFailureDismissed:
            guard step == .creatingCard else { return nil }
            return .loyaltyDecision

        case .claimCardFailureDismissed(let kind, let source):
            guard step == .scanReview else { return nil }
            switch kind {
            case .alreadyClaimedByOtherUser:
                // Matrix text says "back to scanning", written before `manualCardEntry`
                // existed as a first-class step — route by claim source so a
                // manual-entry failure doesn't dump the user onto the camera.
                return source == .manualEntry ? .manualCardEntry : .scanning
            case .generic:
                return .loyaltyDecision
            }

        case .unresumableScanReviewFallback:
            guard step == .scanReview else { return nil }
            return .loyaltyDecision
        }
    }

    func canGoBack(from step: OnboardingStep) -> Bool {
        backDestination(from: step) != nil
    }

    /// `nil` marks the three steps with no back affordance at all — matching
    /// "can't step back once a create/claim is in flight or done" (the system
    /// swipe-back gesture is disabled for these too, at the screen level).
    private func backDestination(from step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .name, .creatingCard, .scanReview:
            return nil
        case .language:
            return .name
        case .loyaltyDecision:
            return .language
        case .scannerPermission, .scanning, .manualCardEntry:
            return .loyaltyDecision
        }
    }
}
