import XCTest
@testable import FeatureOnboarding

/// Every transition here mirrors a row/column in the Task 1.2 transition matrix
/// (`plans/ios-onboarding-flow_fc28f096.plan.md`). No mocks needed — `OnboardingRouter`
/// is a pure function of (step, transition).
final class OnboardingRouterTests: XCTestCase {
    private let router = OnboardingRouter()

    // MARK: Back navigation

    func testNameHasNoBackAffordance() {
        XCTAssertFalse(router.canGoBack(from: .name))
        XCTAssertNil(router.nextStep(from: .name, on: .back))
    }

    func testCreatingCardHasNoBackAffordance() {
        XCTAssertFalse(router.canGoBack(from: .creatingCard))
        XCTAssertNil(router.nextStep(from: .creatingCard, on: .back))
    }

    func testProcessingScanHasNoBackAffordance() {
        XCTAssertFalse(router.canGoBack(from: .processingScan))
        XCTAssertNil(router.nextStep(from: .processingScan, on: .back))
    }

    func testLanguageBacksToName() {
        XCTAssertTrue(router.canGoBack(from: .language))
        XCTAssertEqual(router.nextStep(from: .language, on: .back), .name)
    }

    func testLoyaltyDecisionBacksToLanguage() {
        XCTAssertEqual(router.nextStep(from: .loyaltyDecision, on: .back), .language)
    }

    func testScannerPermissionScanningAndManualEntryAllBackToLoyaltyDecision() {
        XCTAssertEqual(router.nextStep(from: .scannerPermission, on: .back), .loyaltyDecision)
        XCTAssertEqual(router.nextStep(from: .scanning, on: .back), .loyaltyDecision)
        XCTAssertEqual(router.nextStep(from: .manualCardEntry, on: .back), .loyaltyDecision)
    }

    // MARK: Forward transitions

    func testNameConfirmedGoesToLanguage() {
        XCTAssertEqual(router.nextStep(from: .name, on: .nameConfirmed), .language)
    }

    func testLanguageConfirmedGoesToLoyaltyDecision() {
        XCTAssertEqual(router.nextStep(from: .language, on: .languageConfirmed), .loyaltyDecision)
    }

    func testLoyaltyDecisionNewCustomerGoesToCreatingCard() {
        XCTAssertEqual(
            router.nextStep(from: .loyaltyDecision, on: .loyaltyDecisionConfirmed(.newCustomer)),
            .creatingCard
        )
    }

    func testLoyaltyDecisionExistingCardGoesToScannerPermission() {
        XCTAssertEqual(
            router.nextStep(from: .loyaltyDecision, on: .loyaltyDecisionConfirmed(.existingCard)),
            .scannerPermission
        )
    }

    func testCameraPermissionGrantedGoesToScanning() {
        XCTAssertEqual(router.nextStep(from: .scannerPermission, on: .cameraPermissionGranted), .scanning)
    }

    func testManualCardEntryChosenGoesToManualCardEntry() {
        XCTAssertEqual(router.nextStep(from: .scannerPermission, on: .manualCardEntryChosen), .manualCardEntry)
        XCTAssertEqual(router.nextStep(from: .scanning, on: .manualCardEntryChosen), .manualCardEntry)
    }

    func testCodeSubmittedForClaimGoesToProcessingScanFromScanningOrManualEntry() {
        XCTAssertEqual(router.nextStep(from: .scanning, on: .codeSubmittedForClaim), .processingScan)
        XCTAssertEqual(router.nextStep(from: .manualCardEntry, on: .codeSubmittedForClaim), .processingScan)
    }

    // MARK: Failure dismiss targets

    func testCreateCardFailureDismissedGoesToLoyaltyDecision() {
        XCTAssertEqual(router.nextStep(from: .creatingCard, on: .createCardFailureDismissed), .loyaltyDecision)
    }

    func testAlreadyClaimedDismissedFromScanGoesToScanning() {
        XCTAssertEqual(
            router.nextStep(
                from: .processingScan,
                on: .claimCardFailureDismissed(.alreadyClaimedByOtherUser, source: .scanner)
            ),
            .scanning
        )
    }

    func testAlreadyClaimedDismissedFromManualEntryGoesToManualCardEntry() {
        XCTAssertEqual(
            router.nextStep(
                from: .processingScan,
                on: .claimCardFailureDismissed(.alreadyClaimedByOtherUser, source: .manualEntry)
            ),
            .manualCardEntry
        )
    }

    func testGenericClaimFailureDismissedGoesToLoyaltyDecisionRegardlessOfSource() {
        XCTAssertEqual(
            router.nextStep(from: .processingScan, on: .claimCardFailureDismissed(.generic, source: .scanner)),
            .loyaltyDecision
        )
        XCTAssertEqual(
            router.nextStep(from: .processingScan, on: .claimCardFailureDismissed(.generic, source: .manualEntry)),
            .loyaltyDecision
        )
    }

    // MARK: Resume fallback

    func testUnresumableProcessingScanFallsBackToLoyaltyDecision() {
        XCTAssertEqual(router.nextStep(from: .processingScan, on: .unresumableProcessingScanFallback), .loyaltyDecision)
    }

    // MARK: Illegal source steps rejected

    func testNameConfirmedRejectedFromOtherSteps() {
        XCTAssertNil(router.nextStep(from: .language, on: .nameConfirmed))
        XCTAssertNil(router.nextStep(from: .processingScan, on: .nameConfirmed))
    }

    func testLanguageConfirmedRejectedFromOtherSteps() {
        XCTAssertNil(router.nextStep(from: .name, on: .languageConfirmed))
        XCTAssertNil(router.nextStep(from: .loyaltyDecision, on: .languageConfirmed))
    }

    func testLoyaltyDecisionConfirmedRejectedFromOtherSteps() {
        XCTAssertNil(router.nextStep(from: .name, on: .loyaltyDecisionConfirmed(.newCustomer)))
        XCTAssertNil(router.nextStep(from: .creatingCard, on: .loyaltyDecisionConfirmed(.existingCard)))
    }

    func testCameraPermissionGrantedRejectedOutsideScannerPermission() {
        XCTAssertNil(router.nextStep(from: .scanning, on: .cameraPermissionGranted))
        XCTAssertNil(router.nextStep(from: .loyaltyDecision, on: .cameraPermissionGranted))
    }

    func testManualCardEntryChosenRejectedOutsidePermissionOrScanning() {
        XCTAssertNil(router.nextStep(from: .loyaltyDecision, on: .manualCardEntryChosen))
        XCTAssertNil(router.nextStep(from: .name, on: .manualCardEntryChosen))
    }

    func testCodeSubmittedForClaimRejectedOutsideScanningOrManualEntry() {
        XCTAssertNil(router.nextStep(from: .scannerPermission, on: .codeSubmittedForClaim))
        XCTAssertNil(router.nextStep(from: .loyaltyDecision, on: .codeSubmittedForClaim))
    }

    func testCreateCardFailureDismissedRejectedOutsideCreatingCard() {
        XCTAssertNil(router.nextStep(from: .loyaltyDecision, on: .createCardFailureDismissed))
    }

    func testClaimCardFailureDismissedRejectedOutsideProcessingScan() {
        XCTAssertNil(
            router.nextStep(
                from: .scanning,
                on: .claimCardFailureDismissed(.alreadyClaimedByOtherUser, source: .scanner)
            )
        )
    }

    func testUnresumableProcessingScanFallbackRejectedOutsideProcessingScan() {
        XCTAssertNil(router.nextStep(from: .creatingCard, on: .unresumableProcessingScanFallback))
    }

    // MARK: Exhaustiveness

    func testEveryStepHasAWellDefinedCanGoBackAnswer() {
        for step in OnboardingStep.allCases {
            _ = router.canGoBack(from: step) // exercises every case; crashes on missing switch coverage
        }
    }

    // MARK: Exhaustive rejection (added beyond the original iOS samples)

    func testNameConfirmedRejectedFromEveryStepExceptName() {
        assertRejectedFromEveryStepExcept(
            validSources: [.name],
            transition: .nameConfirmed
        )
    }

    func testLanguageConfirmedRejectedFromEveryStepExceptLanguage() {
        assertRejectedFromEveryStepExcept(
            validSources: [.language],
            transition: .languageConfirmed
        )
    }

    func testLoyaltyDecisionConfirmedRejectedFromEveryStepExceptLoyaltyDecisionForBothBranches() {
        XCTAssertFalse(OnboardingLoyaltyBranch.allCases.isEmpty, "loyalty branches must be non-empty")
        for branch in OnboardingLoyaltyBranch.allCases {
            assertRejectedFromEveryStepExcept(
                validSources: [.loyaltyDecision],
                transition: .loyaltyDecisionConfirmed(branch)
            )
        }
    }

    func testCameraPermissionGrantedRejectedFromEveryStepExceptScannerPermission() {
        assertRejectedFromEveryStepExcept(
            validSources: [.scannerPermission],
            transition: .cameraPermissionGranted
        )
    }

    func testManualCardEntryChosenRejectedFromEveryStepExceptScannerPermissionAndScanning() {
        assertRejectedFromEveryStepExcept(
            validSources: [.scannerPermission, .scanning],
            transition: .manualCardEntryChosen
        )
    }

    func testCodeSubmittedForClaimRejectedFromEveryStepExceptScanningAndManualCardEntry() {
        assertRejectedFromEveryStepExcept(
            validSources: [.scanning, .manualCardEntry],
            transition: .codeSubmittedForClaim
        )
    }

    func testCreateCardFailureDismissedRejectedFromEveryStepExceptCreatingCard() {
        assertRejectedFromEveryStepExcept(
            validSources: [.creatingCard],
            transition: .createCardFailureDismissed
        )
    }

    func testClaimCardFailureDismissedRejectedFromEveryStepExceptProcessingScanForEveryKindAndSource() {
        // OnboardingClaimFailureKind is Equatable, not CaseIterable — list cases explicitly.
        let kinds: [OnboardingClaimFailureKind] = [.alreadyClaimedByOtherUser, .generic]
        // OnboardingClaimSource is Equatable, not CaseIterable. nil is no recorded attempt.
        let sources: [OnboardingClaimSource?] = [.scanner, .manualEntry, nil]
        XCTAssertFalse(kinds.isEmpty, "claim failure kinds must be non-empty")
        XCTAssertFalse(sources.isEmpty, "claim sources including nil must be non-empty")
        for kind in kinds {
            for source in sources {
                assertRejectedFromEveryStepExcept(
                    validSources: [.processingScan],
                    transition: .claimCardFailureDismissed(kind, source: source)
                )
            }
        }
    }

    func testUnresumableProcessingScanFallbackRejectedFromEveryStepExceptProcessingScan() {
        assertRejectedFromEveryStepExcept(
            validSources: [.processingScan],
            transition: .unresumableProcessingScanFallback
        )
    }

    func testBackIsRejectedExactlyFromNameCreatingCardAndProcessingScan() {
        let rejected: Set<OnboardingStep> = [.name, .creatingCard, .processingScan]
        let accepted = OnboardingStep.allCases.filter { !rejected.contains($0) }
        XCTAssertFalse(rejected.isEmpty, "back-rejected steps must be non-empty")
        XCTAssertFalse(accepted.isEmpty, "back-accepted steps must be non-empty")
        for step in OnboardingStep.allCases {
            let destination = router.nextStep(from: step, on: .back)
            XCTAssertEqual(
                destination == nil,
                rejected.contains(step),
                "back from \(step) returned \(String(describing: destination)); " +
                    "expected nil exactly for name, creatingCard, processingScan"
            )
        }
    }

    func testCanGoBackMatchesBackDestinationForEveryStep() {
        let noBack: Set<OnboardingStep> = [.name, .creatingCard, .processingScan]
        let withBack = OnboardingStep.allCases.filter { !noBack.contains($0) }
        XCTAssertFalse(noBack.isEmpty, "steps without back must be non-empty")
        XCTAssertFalse(withBack.isEmpty, "steps with back must be non-empty")
        for step in OnboardingStep.allCases {
            let destination = router.nextStep(from: step, on: .back)
            let canGoBack = router.canGoBack(from: step)
            XCTAssertEqual(
                canGoBack,
                destination != nil,
                "canGoBack(\(step))=\(canGoBack) should match a non-null back destination " +
                    "(destination=\(String(describing: destination)))"
            )
            XCTAssertEqual(
                canGoBack,
                !noBack.contains(step),
                "canGoBack(\(step))=\(canGoBack) should be false exactly for " +
                    "name, creatingCard, processingScan"
            )
        }
    }

    /// `validSources` is the matrix's legal source set for `transition`. Every other
    /// `OnboardingStep.allCases` value must be rejected. Both sets are asserted
    /// non-empty so a renamed step cannot turn the loop into a no-op.
    private func assertRejectedFromEveryStepExcept(
        validSources: Set<OnboardingStep>,
        transition: OnboardingRouter.Transition,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let rejected = OnboardingStep.allCases.filter { !validSources.contains($0) }
        XCTAssertFalse(
            validSources.isEmpty,
            "valid sources for \(transition) must be non-empty",
            file: file,
            line: line
        )
        XCTAssertFalse(
            rejected.isEmpty,
            "rejected sources for \(transition) must be non-empty",
            file: file,
            line: line
        )
        for step in rejected {
            XCTAssertNil(
                router.nextStep(from: step, on: transition),
                "\(transition) from \(step) should be rejected",
                file: file,
                line: line
            )
        }
    }
}
