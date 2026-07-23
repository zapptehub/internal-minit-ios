import Foundation

extension OnboardingStep {
    /// Continuous progress for the top bar. Name lands ~16% (Task 1.1); later steps
    /// pace through the wizard. The create/claim finish steps sit near the end while
    /// processing, and fill completely once the success status card is showing
    /// (`isFinishComplete`).
    func progressFraction(isFinishComplete: Bool = false) -> Double {
        switch self {
        case .name: return 0.16
        case .language: return 0.33
        case .loyaltyDecision: return 0.5
        case .scannerPermission, .scanning, .manualCardEntry: return 0.66
        case .creatingCard, .processingScan:
            return isFinishComplete ? 1.0 : 0.85
        }
    }
}
