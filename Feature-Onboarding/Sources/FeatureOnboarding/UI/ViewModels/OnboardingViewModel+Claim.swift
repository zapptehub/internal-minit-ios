/// `scanning` → `processingScan` (existing-card branch) — claiming a code, whether from a
/// recognized scan or the manual-entry fallback, plus retry and the claim-failure
/// alert's two different dismiss targets.
extension OnboardingViewModel {
    public func didScanCode(_ code: String) {
        // Ignore late/duplicate recognitions once we've already moved past `scanning` —
        // the scanner screen (Task 4.4) owns its own debouncing, this is a second guard.
        guard step == .scanning, !isLoading else { return }
        analytics.trackQRCodeScanned(file: #fileID)
        guard advance(via: .codeSubmittedForClaim) else { return }
        performClaim(code: code, source: .scanner)
    }

    public func submitManualCardCode(_ code: String) {
        // Mirror `didScanCode`'s step guard so a stale call site cannot jump into
        // `processingScan` + claim from an unrelated screen.
        guard step == .manualCardEntry, !isLoading else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        guard advance(via: .codeSubmittedForClaim) else { return }
        performClaim(code: trimmed, source: .manualEntry)
    }

    func performClaim(code: String, source: OnboardingClaimSource) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        lastAttemptedCardCode = code
        lastClaimSource = source
        analytics.trackClaimCardAttempted(source: source.rawValue, file: #fileID)
        Task {
            do {
                let card = try await loyaltyCardRepository.claimCard(userId: userId, code: code)
                analytics.trackClaimCardSucceeded(source: source.rawValue, file: #fileID)
                complete(with: card)
            } catch {
                isLoading = false
                let kind = Self.claimFailureKind(for: error)
                analytics.trackClaimCardFailed(
                    reason: Self.analyticsReason(for: error),
                    source: source.rawValue,
                    file: #fileID
                )
                activeAlert = .claimCardFailed(kind: kind)
            }
        }
    }

    public func retryClaimCard() {
        guard !isLoading, let code = lastAttemptedCardCode, let source = lastClaimSource else { return }
        activeAlert = nil
        analytics.trackRetryTapped(step: OnboardingStep.processingScan.rawValue, file: #fileID)
        performClaim(code: code, source: source)
    }

    public func dismissClaimFailure() {
        guard case .claimCardFailed(let kind) = activeAlert else {
            activeAlert = nil
            return
        }

        activeAlert = nil
        if kind == .generic {
            selectedBranch = nil
        }
        advance(via: .claimCardFailureDismissed(kind, source: lastClaimSource))
    }

    private static func claimFailureKind(for error: Error) -> OnboardingClaimFailureKind {
        if let loyaltyError = error as? LoyaltyCardError, loyaltyError == .alreadyClaimed {
            return .alreadyClaimedByOtherUser
        }
        return .generic
    }
}
