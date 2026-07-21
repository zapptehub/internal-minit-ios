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

    func testScanReviewHasNoBackAffordance() {
        XCTAssertFalse(router.canGoBack(from: .scanReview))
        XCTAssertNil(router.nextStep(from: .scanReview, on: .back))
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

    func testCodeSubmittedForClaimGoesToScanReviewFromScanningOrManualEntry() {
        XCTAssertEqual(router.nextStep(from: .scanning, on: .codeSubmittedForClaim), .scanReview)
        XCTAssertEqual(router.nextStep(from: .manualCardEntry, on: .codeSubmittedForClaim), .scanReview)
    }

    // MARK: Failure dismiss targets

    func testCreateCardFailureDismissedGoesToLoyaltyDecision() {
        XCTAssertEqual(router.nextStep(from: .creatingCard, on: .createCardFailureDismissed), .loyaltyDecision)
    }

    func testAlreadyClaimedDismissedFromScanGoesToScanning() {
        XCTAssertEqual(
            router.nextStep(
                from: .scanReview,
                on: .claimCardFailureDismissed(.alreadyClaimedByOtherUser, source: .scanner)
            ),
            .scanning
        )
    }

    func testAlreadyClaimedDismissedFromManualEntryGoesToManualCardEntry() {
        XCTAssertEqual(
            router.nextStep(
                from: .scanReview,
                on: .claimCardFailureDismissed(.alreadyClaimedByOtherUser, source: .manualEntry)
            ),
            .manualCardEntry
        )
    }

    func testGenericClaimFailureDismissedGoesToLoyaltyDecisionRegardlessOfSource() {
        XCTAssertEqual(
            router.nextStep(from: .scanReview, on: .claimCardFailureDismissed(.generic, source: .scanner)),
            .loyaltyDecision
        )
        XCTAssertEqual(
            router.nextStep(from: .scanReview, on: .claimCardFailureDismissed(.generic, source: .manualEntry)),
            .loyaltyDecision
        )
    }

    // MARK: Resume fallback

    func testUnresumableScanReviewFallsBackToLoyaltyDecision() {
        XCTAssertEqual(router.nextStep(from: .scanReview, on: .unresumableScanReviewFallback), .loyaltyDecision)
    }

    // MARK: Illegal source steps rejected

    func testNameConfirmedRejectedFromOtherSteps() {
        XCTAssertNil(router.nextStep(from: .language, on: .nameConfirmed))
        XCTAssertNil(router.nextStep(from: .scanReview, on: .nameConfirmed))
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

    func testClaimCardFailureDismissedRejectedOutsideScanReview() {
        XCTAssertNil(
            router.nextStep(
                from: .scanning,
                on: .claimCardFailureDismissed(.alreadyClaimedByOtherUser, source: .scanner)
            )
        )
    }

    func testUnresumableScanReviewFallbackRejectedOutsideScanReview() {
        XCTAssertNil(router.nextStep(from: .creatingCard, on: .unresumableScanReviewFallback))
    }

    // MARK: Exhaustiveness

    func testEveryStepHasAWellDefinedCanGoBackAnswer() {
        for step in OnboardingStep.allCases {
            _ = router.canGoBack(from: step) // exercises every case; crashes on missing switch coverage
        }
    }
}
