import Foundation

extension OnboardingStep {
    /// Approximate continuous progress for the top bar. Name lands ~16% (Task 1.1);
    /// later steps are evenly paced through the rest of the wizard until Task 4.3–4.5
    /// refine per-screen values against their checklists.
    var progressFraction: Double {
        switch self {
        case .name: return 0.16
        case .language: return 0.33
        case .loyaltyDecision: return 0.5
        case .scannerPermission, .scanning, .manualCardEntry: return 0.66
        case .creatingCard, .scanReview: return 0.85
        }
    }
}
