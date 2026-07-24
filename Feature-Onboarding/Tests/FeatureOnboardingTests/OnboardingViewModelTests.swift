import XCTest
import OnboardingTestUtilities
import DataProfile
import DataLoyaltyCard
@testable import FeatureOnboarding

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private func makeViewModel(
        userId: String = "user-1",
        profileRepository: FakeProfileRepository = FakeProfileRepository(),
        loyaltyCardRepository: FakeLoyaltyCardRepository = FakeLoyaltyCardRepository(),
        progressStore: FakeOnboardingProgressStore? = nil,
        analytics: MockOnboardingAnalyticsTracking = MockOnboardingAnalyticsTracking(),
        preferredLanguages: [String] = ["en-US"],
        onCompleted: @escaping () -> Void = {}
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            userId: userId,
            profileRepository: profileRepository,
            loyaltyCardRepository: loyaltyCardRepository,
            progressStore: progressStore ?? FakeOnboardingProgressStore(),
            analytics: analytics,
            preferredLanguages: preferredLanguages,
            onCompleted: onCompleted
        )
    }

    private func settle() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    /// Walks name → language → loyaltyDecision via the router without async profile
    /// work, so mid-flow tests start on a legal source step under the source-aware
    /// router (illegal transitions now correctly no-op).
    private func advanceToLoyaltyDecision(_ vm: OnboardingViewModel) {
        XCTAssertTrue(vm.advance(via: .nameConfirmed))
        XCTAssertTrue(vm.advance(via: .languageConfirmed))
        XCTAssertEqual(vm.step, .loyaltyDecision)
    }

    private func advanceToScannerPermission(_ vm: OnboardingViewModel) {
        advanceToLoyaltyDecision(vm)
        vm.selectBranch(.existingCard)
        vm.continueFromLoyaltyDecision()
        XCTAssertEqual(vm.step, .scannerPermission)
    }

    private func advanceToScanning(_ vm: OnboardingViewModel) {
        advanceToScannerPermission(vm)
        vm.cameraPermissionGranted()
        XCTAssertEqual(vm.step, .scanning)
    }

    private func advanceToManualCardEntry(_ vm: OnboardingViewModel) {
        advanceToScannerPermission(vm)
        vm.cameraPermissionDenied()
        vm.chooseManualCardEntry()
        XCTAssertEqual(vm.step, .manualCardEntry)
    }

    // MARK: Pre-selection

    func testInitPreSelectsSlovakFromDeviceLocale() {
        let vm = makeViewModel(preferredLanguages: ["sk-SK"])
        XCTAssertEqual(vm.selectedLanguage, .sk)
    }

    func testInitPreSelectsHungarianFromDeviceLocale() {
        let vm = makeViewModel(preferredLanguages: ["hu-HU"])
        XCTAssertEqual(vm.selectedLanguage, .hu)
    }

    func testInitFallsBackToEnglishForUnsupportedDeviceLocale() {
        let vm = makeViewModel(preferredLanguages: ["fr-FR"])
        XCTAssertEqual(vm.selectedLanguage, .en)
    }

    func testCanContinueFromLanguageIsAlwaysTrue() {
        XCTAssertTrue(makeViewModel().canContinueFromLanguage)
    }

    // MARK: Name step

    func testContinueFromNameWithEmptyNameFailsValidation() {
        let analytics = MockOnboardingAnalyticsTracking()
        let vm = makeViewModel(analytics: analytics)

        vm.continueFromName()

        XCTAssertTrue(analytics.trackNameValidationFailedCalled)
        XCTAssertEqual(vm.step, .name)
    }

    func testContinueFromNameTrimsAndSavesProfileThenAdvances() async {
        let profileRepo = FakeProfileRepository()
        let store = FakeOnboardingProgressStore()
        let vm = makeViewModel(profileRepository: profileRepo, progressStore: store)
        vm.name = "  Iveta  "

        vm.continueFromName()
        await settle()

        XCTAssertEqual(profileRepo.updatedName, "Iveta")
        XCTAssertEqual(vm.step, .language)
        XCTAssertEqual(try store.load(userId: "user-1")?.step, .supported(.language))
        XCTAssertFalse(vm.isLoading)
    }

    func testContinueFromNamePropagatesProfileFailure() async {
        let profileRepo = FakeProfileRepository()
        profileRepo.errorToThrow = SampleError.boom
        let vm = makeViewModel(profileRepository: profileRepo)
        vm.name = "Iveta"

        vm.continueFromName()
        await settle()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.step, .name)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: Language step

    func testSelectLanguageAppliesImmediatelyWithoutPersisting() {
        let store = FakeOnboardingProgressStore()
        let vm = makeViewModel(progressStore: store)

        vm.selectLanguage(.hu)

        XCTAssertEqual(vm.selectedLanguage, .hu)
        XCTAssertNil(try? store.load(userId: "user-1"))
    }

    func testContinueFromLanguagePersistsLanguageAndAdvances() {
        let store = FakeOnboardingProgressStore()
        let vm = makeViewModel(progressStore: store)
        XCTAssertTrue(vm.advance(via: .nameConfirmed))
        vm.selectLanguage(.sk)

        vm.continueFromLanguage()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertEqual(try store.load(userId: "user-1")?.language, .sk)
    }

    func testGoBackFromLanguageReturnsToName() async {
        let vm = makeViewModel()
        vm.name = "Iveta"
        vm.continueFromName()
        await settle()
        XCTAssertEqual(vm.step, .language)

        vm.goBack()

        XCTAssertEqual(vm.step, .name)
    }

    // MARK: Loyalty decision step

    func testContinueFromLoyaltyDecisionWithoutSelectionDoesNothing() {
        let vm = makeViewModel()
        advanceToLoyaltyDecision(vm)

        vm.continueFromLoyaltyDecision()

        XCTAssertEqual(vm.step, .loyaltyDecision)
    }

    func testSelectBranchThenContinueWithNewCustomerCreatesCard() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToLoyaltyDecision(vm)

        vm.selectBranch(.newCustomer)
        vm.continueFromLoyaltyDecision()
        await settle()

        XCTAssertEqual(vm.step, .creatingCard)
        XCTAssertNotNil(vm.linkedCard)
        XCTAssertEqual(loyaltyRepo.createCardCallCount, 1)
    }

    func testSelectBranchThenContinueWithExistingCardMovesToScannerPermission() {
        let vm = makeViewModel()
        advanceToLoyaltyDecision(vm)

        vm.selectBranch(.existingCard)
        vm.continueFromLoyaltyDecision()

        XCTAssertEqual(vm.step, .scannerPermission)
    }

    // MARK: Create-card step

    func testCreateCardFailureShowsAlertAndRetryReissuesIdempotently() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.createCardErrorToThrow = SampleError.boom
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToLoyaltyDecision(vm)

        vm.selectBranch(.newCustomer)
        vm.continueFromLoyaltyDecision()
        await settle()

        XCTAssertEqual(vm.activeAlert, .createCardFailed)
        XCTAssertNil(vm.linkedCard)

        loyaltyRepo.createCardErrorToThrow = nil
        vm.retryCreateCard()
        await settle()

        XCTAssertNil(vm.activeAlert)
        XCTAssertNotNil(vm.linkedCard)
        XCTAssertEqual(loyaltyRepo.createCardCallCount, 2)
    }

    func testDismissCreateCardFailureReturnsToLoyaltyDecisionWithNoRowSelected() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.createCardErrorToThrow = SampleError.boom
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToLoyaltyDecision(vm)
        vm.selectBranch(.newCustomer)
        vm.continueFromLoyaltyDecision()
        await settle()

        vm.dismissCreateCardFailure()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertNil(vm.selectedBranch)
        XCTAssertNil(vm.activeAlert)
    }

    // MARK: Scanner permission / manual entry

    func testCameraPermissionGrantedAdvancesToScanning() {
        let vm = makeViewModel()
        advanceToScannerPermission(vm)

        vm.cameraPermissionGranted()

        XCTAssertEqual(vm.step, .scanning)
    }

    func testCameraPermissionDeniedShowsAlert() {
        let vm = makeViewModel()
        advanceToScannerPermission(vm)
        vm.cameraPermissionDenied()
        XCTAssertEqual(vm.activeAlert, .cameraPermissionDenied)
    }

    func testDismissCameraPermissionAlertReturnsToLoyaltyDecisionAndClearsAlert() {
        let vm = makeViewModel()
        advanceToScannerPermission(vm)
        vm.cameraPermissionDenied()

        vm.dismissCameraPermissionAlert()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertEqual(vm.selectedBranch, .existingCard)
        XCTAssertNil(vm.activeAlert)
    }

    func testGoBackClearsActiveAlert() {
        let vm = makeViewModel()
        advanceToScannerPermission(vm)
        vm.cameraPermissionDenied()

        vm.goBack()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertNil(vm.activeAlert)
    }

    func testChooseManualCardEntryMovesToManualCardEntryStep() {
        let vm = makeViewModel()
        advanceToManualCardEntry(vm)

        XCTAssertEqual(vm.step, .manualCardEntry)
        XCTAssertNil(vm.activeAlert)
    }

    func testGoBackFromScannerPermissionReturnsToLoyaltyDecisionKeepingBranchSelected() {
        let vm = makeViewModel()
        advanceToScannerPermission(vm)

        vm.goBack()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertEqual(vm.selectedBranch, .existingCard)
    }

    // MARK: Scanning / claim

    func testDidScanCodeClaimsCardAndCompletes() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToScanning(vm)

        vm.didScanCode("MINIT-ABC123")
        await settle()

        XCTAssertEqual(vm.step, .processingScan)
        XCTAssertNotNil(vm.linkedCard)
        XCTAssertEqual(loyaltyRepo.claimedCodes, ["MINIT-ABC123"])
    }

    func testDidScanCodeIgnoredWhenNotOnScanningStep() {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)

        vm.didScanCode("MINIT-ABC123")

        XCTAssertEqual(vm.step, .name)
        XCTAssertTrue(loyaltyRepo.claimedCodes.isEmpty)
    }

    func testAlreadyClaimedFailureDismissReturnsToScanning() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.claimCardErrorToThrow = LoyaltyCardError.alreadyClaimed
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToScanning(vm)
        vm.didScanCode("MINIT-TAKEN")
        await settle()

        XCTAssertEqual(vm.activeAlert, .claimCardFailed(kind: .alreadyClaimedByOtherUser))

        vm.dismissClaimFailure()

        XCTAssertEqual(vm.step, .scanning)
        XCTAssertNil(vm.activeAlert)
    }

    func testAlreadyClaimedFailureFromManualEntryDismissReturnsToManualCardEntry() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.claimCardErrorToThrow = LoyaltyCardError.alreadyClaimed
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToManualCardEntry(vm)
        vm.submitManualCardCode("MINIT-TAKEN")
        await settle()

        XCTAssertEqual(vm.activeAlert, .claimCardFailed(kind: .alreadyClaimedByOtherUser))

        vm.dismissClaimFailure()

        XCTAssertEqual(vm.step, .manualCardEntry)
        XCTAssertNil(vm.activeAlert)
    }

    func testGenericClaimFailureDismissReturnsToLoyaltyDecision() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.claimCardErrorToThrow = LoyaltyCardError.notFound
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToScanning(vm)
        vm.didScanCode("UNKNOWN")
        await settle()

        XCTAssertEqual(vm.activeAlert, .claimCardFailed(kind: .generic))

        vm.dismissClaimFailure()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertNil(vm.selectedBranch)
    }

    func testRetryClaimCardReissuesSameCodeIdempotently() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.claimCardErrorToThrow = SampleError.boom
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToScanning(vm)
        vm.didScanCode("MINIT-RETRY")
        await settle()

        loyaltyRepo.claimCardErrorToThrow = nil
        vm.retryClaimCard()
        await settle()

        XCTAssertNotNil(vm.linkedCard)
        XCTAssertEqual(loyaltyRepo.claimedCodes, ["MINIT-RETRY", "MINIT-RETRY"])
    }

    func testSubmitManualCardCodeClaimsAndCompletes() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToManualCardEntry(vm)

        vm.submitManualCardCode("  MINIT-MANUAL  ")
        await settle()

        XCTAssertEqual(loyaltyRepo.claimedCodes, ["MINIT-MANUAL"])
        XCTAssertNotNil(vm.linkedCard)
    }

    func testSubmitManualCardCodeIgnoresBlankInput() {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToManualCardEntry(vm)

        vm.submitManualCardCode("   ")

        XCTAssertTrue(loyaltyRepo.claimedCodes.isEmpty)
        XCTAssertEqual(vm.step, .manualCardEntry)
    }

    func testSubmitManualCardCodeIgnoredWhenNotOnManualCardEntryStep() {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)

        vm.submitManualCardCode("MINIT-ABC123")

        XCTAssertEqual(vm.step, .name)
        XCTAssertTrue(loyaltyRepo.claimedCodes.isEmpty)
    }

    // MARK: Completion

    func testTapEnterMinitNoOpsWithoutLinkedCard() {
        var completedCalled = false
        let vm = makeViewModel(onCompleted: { completedCalled = true })

        vm.tapEnterMinit()

        XCTAssertFalse(completedCalled)
    }

    func testTapEnterMinitFiresOnCompletedOnceLinked() async {
        var completedCalled = false
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo, onCompleted: { completedCalled = true })
        advanceToLoyaltyDecision(vm)
        vm.selectBranch(.newCustomer)
        vm.continueFromLoyaltyDecision()
        await settle()

        vm.tapEnterMinit()

        XCTAssertTrue(completedCalled)
    }

    func testCompletionClearsLocalProgress() async {
        let store = FakeOnboardingProgressStore()
        let vm = makeViewModel(progressStore: store)
        advanceToLoyaltyDecision(vm)
        vm.selectBranch(.newCustomer)

        vm.continueFromLoyaltyDecision()
        await settle()

        XCTAssertNil(try? store.load(userId: "user-1"))
    }

    // MARK: Bootstrap / resume

    func testBootstrapWithExistingLinkedCardCompletesImmediately() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.linkedCard = LoyaltyCardData(code: "MINIT-EXISTING", ownerUserId: "user-1", points: 40)
        let store = FakeOnboardingProgressStore()
        try? store.save(OnboardingProgress(step: .language), userId: "user-1")
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo, progressStore: store)

        await vm.bootstrap()

        XCTAssertNotNil(vm.linkedCard)
        XCTAssertEqual(vm.step, .creatingCard)
        XCTAssertFalse(vm.isBootstrapping)
        XCTAssertNil(try? store.load(userId: "user-1"))
    }

    func testBootstrapFetchFailureSurfacesRetryableAlertWithoutAdvancing() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.fetchLinkedCardErrorToThrow = SampleError.boom
        let store = FakeOnboardingProgressStore()
        try? store.save(OnboardingProgress(step: .creatingCard), userId: "user-1")
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo, progressStore: store)

        await vm.bootstrap()

        XCTAssertEqual(vm.activeAlert, .bootstrapFetchFailed)
        XCTAssertEqual(vm.step, .name)
        XCTAssertEqual(loyaltyRepo.createCardCallCount, 0)
        XCTAssertEqual(try store.load(userId: "user-1")?.step, .supported(.creatingCard))
    }

    func testRetryBootstrapClearsAlertAndCompletesWhenFetchSucceeds() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        loyaltyRepo.fetchLinkedCardErrorToThrow = SampleError.boom
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)

        await vm.bootstrap()
        XCTAssertEqual(vm.activeAlert, .bootstrapFetchFailed)

        loyaltyRepo.fetchLinkedCardErrorToThrow = nil
        loyaltyRepo.linkedCard = LoyaltyCardData(code: "MINIT-EXISTING", ownerUserId: "user-1", points: 40)
        vm.retryBootstrap()
        await settle()

        XCTAssertNil(vm.activeAlert)
        XCTAssertNotNil(vm.linkedCard)
        XCTAssertEqual(vm.step, .creatingCard)
    }

    func testBootstrapResumesPersistedStepAndLanguage() async {
        let store = FakeOnboardingProgressStore()
        try? store.save(OnboardingProgress(step: .loyaltyDecision, language: .hu), userId: "user-1")
        let analytics = MockOnboardingAnalyticsTracking()
        let vm = makeViewModel(progressStore: store, analytics: analytics)

        await vm.bootstrap()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertEqual(vm.selectedLanguage, .hu)
        XCTAssertTrue(analytics.trackOnboardingResumedCalled)
        XCTAssertEqual(analytics.trackOnboardingResumedStep, "loyaltyDecision")
    }

    func testBootstrapWithUnsupportedFutureStepDefaultsToNameWithoutOverwritingStorage() async {
        let store = FakeOnboardingProgressStore()
        try? store.save(
            OnboardingProgress(persistedStep: .unsupported(rawValue: "futureStep"), language: .en),
            userId: "user-1"
        )
        let vm = makeViewModel(progressStore: store)

        await vm.bootstrap()

        XCTAssertEqual(vm.step, .name)
        XCTAssertEqual(try store.load(userId: "user-1")?.step, .unsupported(rawValue: "futureStep"))
    }

    func testBootstrapWithCorruptedProgressClearsStoreAndRestartsAtName() async {
        let store = FakeOnboardingProgressStore()
        try? store.save(OnboardingProgress(step: .language), userId: "user-1")
        store.errorToThrowOnLoad = OnboardingProgressStoreError.corruptedData
        let vm = makeViewModel(progressStore: store)

        await vm.bootstrap()

        XCTAssertEqual(vm.step, .name)
        XCTAssertNotNil(vm.errorMessage)
        store.errorToThrowOnLoad = nil
        XCTAssertNil(try store.load(userId: "user-1"))
    }

    func testBootstrapResumingAtCreatingCardSilentlyRetriesCreate() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let store = FakeOnboardingProgressStore()
        try? store.save(OnboardingProgress(step: .creatingCard), userId: "user-1")
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo, progressStore: store)

        await vm.bootstrap()
        await settle()

        XCTAssertNotNil(vm.linkedCard)
        XCTAssertEqual(loyaltyRepo.createCardCallCount, 1)
    }

    func testBootstrapResumingAtProcessingScanWithNoLinkedCardFallsBackToLoyaltyDecision() async {
        let store = FakeOnboardingProgressStore()
        try? store.save(OnboardingProgress(step: .processingScan), userId: "user-1")
        let vm = makeViewModel(progressStore: store)

        await vm.bootstrap()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertEqual(vm.selectedBranch, .existingCard)
    }

    /// Passive steps (no auto side-effect on resume) must restore exactly as persisted —
    /// covers the matrix's "resume from every persisted step" requirement for everything
    /// that isn't the create/claim special cases above.
    func testBootstrapResumesEveryPassivePersistedStep() async {
        let passiveSteps: [OnboardingStep] = [
            .name,
            .language,
            .loyaltyDecision,
            .scannerPermission,
            .scanning,
            .manualCardEntry
        ]

        for step in passiveSteps {
            let store = FakeOnboardingProgressStore()
            try? store.save(OnboardingProgress(step: step, language: .en), userId: "user-1")
            let vm = makeViewModel(progressStore: store)

            await vm.bootstrap()

            XCTAssertEqual(vm.step, step, "Expected resume to land on \(step)")
            XCTAssertEqual(vm.selectedLanguage, .en)
        }
    }

    // MARK: Scanner helpers / progress

    func testDidTapOpenSettingsClearsCameraDeniedAlertAndTracks() {
        let analytics = MockOnboardingAnalyticsTracking()
        let vm = makeViewModel(analytics: analytics)
        advanceToScannerPermission(vm)
        vm.cameraPermissionDenied()
        XCTAssertEqual(vm.activeAlert, .cameraPermissionDenied)

        vm.didTapOpenSettings()

        XCTAssertNil(vm.activeAlert)
        XCTAssertTrue(analytics.trackOpenSettingsTappedCalled)
    }

    func testGoBackFromScanningReturnsToLoyaltyDecision() {
        let vm = makeViewModel()
        advanceToScanning(vm)

        vm.goBack()

        XCTAssertEqual(vm.step, .loyaltyDecision)
        XCTAssertEqual(vm.selectedBranch, .existingCard)
    }

    func testProgressFractionJumpsToCompleteOnceLinkedCardIsSet() async {
        let loyaltyRepo = FakeLoyaltyCardRepository()
        let vm = makeViewModel(loyaltyCardRepository: loyaltyRepo)
        advanceToLoyaltyDecision(vm)
        vm.selectBranch(.newCustomer)
        XCTAssertEqual(vm.progressFraction, OnboardingStep.loyaltyDecision.progressFraction())

        vm.continueFromLoyaltyDecision()
        XCTAssertEqual(vm.step, .creatingCard)
        XCTAssertEqual(vm.progressFraction, 0.85, accuracy: 0.001)

        await settle()

        XCTAssertNotNil(vm.linkedCard)
        XCTAssertEqual(vm.progressFraction, 1.0, accuracy: 0.001)
    }
}

// MARK: - Fakes

private enum SampleError: Error {
    case boom
}

private final class FakeProfileRepository: ProfileRepository {
    var errorToThrow: Error?
    var updatedName: String?

    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}

    func updateName(userId: String, name: String) async throws {
        if let errorToThrow { throw errorToThrow }
        updatedName = name
    }

    func fetchProfile(userId: String) async throws -> ProfileData? { nil }
}

private final class FakeLoyaltyCardRepository: LoyaltyCardRepository {
    var linkedCard: LoyaltyCardData?
    var createCardErrorToThrow: Error?
    var claimCardErrorToThrow: Error?
    var fetchLinkedCardErrorToThrow: Error?
    private(set) var createCardCallCount = 0
    private(set) var claimedCodes: [String] = []

    func createCard(userId: String) async throws -> LoyaltyCardData {
        createCardCallCount += 1
        if let createCardErrorToThrow { throw createCardErrorToThrow }
        let card = LoyaltyCardData(code: "MINIT-NEW", ownerUserId: userId, points: 0)
        linkedCard = card
        return card
    }

    func claimCard(userId: String, code: String) async throws -> LoyaltyCardData {
        claimedCodes.append(code)
        if let claimCardErrorToThrow { throw claimCardErrorToThrow }
        let card = LoyaltyCardData(code: code, ownerUserId: userId, points: 10)
        linkedCard = card
        return card
    }

    func fetchLinkedCard(userId: String) async throws -> LoyaltyCardData? {
        if let fetchLinkedCardErrorToThrow { throw fetchLinkedCardErrorToThrow }
        return linkedCard
    }
}

@MainActor
private final class FakeOnboardingProgressStore: OnboardingProgressStoring {
    var errorToThrowOnLoad: Error?
    private var progressByUserId: [String: OnboardingProgress] = [:]

    func load(userId: String) throws -> OnboardingProgress? {
        if let errorToThrowOnLoad { throw errorToThrowOnLoad }
        return progressByUserId[userId]
    }

    func save(_ progress: OnboardingProgress, userId: String) throws {
        progressByUserId[userId] = progress
    }

    func clear(userId: String) {
        progressByUserId[userId] = nil
    }
}
