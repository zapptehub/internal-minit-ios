import DataProfile
import XCTest
@testable import FeatureHome

@MainActor
final class HomeScreenModelTests: XCTestCase {
    func testProfileLoadSuccessUsesTheTrimmedName() async {
        let repository = ScriptedProfileRepository(results: [
            .success(ProfileData(name: "  Iveta \n", surname: "Novak", email: "iveta@example.com")),
            .success(nil),
            .success(ProfileData(name: " \n\t", surname: "", email: "")),
        ])
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: repository,
            onLogOut: {}
        )

        await model.loadUserName()
        XCTAssertEqual(model.userName, "Iveta")
        XCTAssertEqual(repository.fetchedUserIds, ["user-1"])

        await model.loadUserName()
        XCTAssertEqual(model.userName, "")

        await model.loadUserName()
        XCTAssertEqual(model.userName, "")
        XCTAssertEqual(repository.fetchedUserIds, ["user-1", "user-1", "user-1"])
        XCTAssertFalse(model.showsLogOutConfirmation)
        XCTAssertFalse(model.isLoggingOut)
    }

    func testProfileLoadFailureClearsTheName() async {
        let repository = ScriptedProfileRepository(results: [
            .success(ProfileData(name: "Iveta", surname: "Novak", email: "iveta@example.com")),
            .failure(ProfileLoadFailed()),
        ])
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: repository,
            onLogOut: {}
        )

        await model.loadUserName()
        XCTAssertEqual(model.userName, "Iveta")

        await model.loadUserName()
        XCTAssertEqual(model.userName, "")
        XCTAssertEqual(repository.fetchedUserIds, ["user-1", "user-1"])
    }

    func testConfirmLogOutSetsLoggingOutAndCallsOnLogOutOnce() {
        var logOuts = 0
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            onLogOut: { logOuts += 1 }
        )

        model.confirmLogOut()
        XCTAssertEqual(logOuts, 0)
        XCTAssertFalse(model.isLoggingOut)

        model.profileTapped()
        XCTAssertTrue(model.showsLogOutConfirmation)
        model.dismissLogOutConfirmation()
        XCTAssertFalse(model.showsLogOutConfirmation)
        model.confirmLogOut()
        XCTAssertEqual(logOuts, 0)
        XCTAssertFalse(model.isLoggingOut)

        model.profileTapped()
        model.hideLogOutConfirmation()
        XCTAssertFalse(model.showsLogOutConfirmation)
        model.confirmLogOut()

        XCTAssertEqual(logOuts, 1)
        XCTAssertTrue(model.isLoggingOut)
        XCTAssertFalse(model.showsLogOutConfirmation)

        model.confirmLogOut()
        model.profileTapped()
        model.confirmLogOut()
        XCTAssertEqual(logOuts, 1)
        XCTAssertFalse(model.showsLogOutConfirmation)
        XCTAssertTrue(model.isLoggingOut)
    }

    func testLoggingOutBlocksInteractionsAndLeavesOpenPopupsUp() {
        var logOuts = 0
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            onLogOut: { logOuts += 1 }
        )
        model.openNotifications()
        model.openLoyaltyCardDetail()
        model.showUnderConstruction(.product)
        model.profileTapped()
        model.confirmLogOut()

        XCTAssertEqual(logOuts, 1)
        XCTAssertTrue(model.isLoggingOut)
        XCTAssertTrue(model.showsNotifications)
        XCTAssertTrue(model.showsLoyaltyCardDetail)
        XCTAssertTrue(model.showsUnderConstructionAlert)
        XCTAssertEqual(model.underConstructionAction, .product)

        model.closeNotifications()
        model.closeLoyaltyCardDetail()
        model.profileTapped()
        model.confirmLogOut()
        model.openNotifications()
        model.showUnderConstruction(.dailyOfferBanner)
        model.showUnderConstruction(.challenge)
        model.showUnderConstruction(.productsSeeAll)
        model.showUnderConstruction(.challengesSeeAll)
        model.showUnderConstruction(.newsAndRecipe)
        model.showUnderConstruction(.newsAndRecipesSeeAll)
        model.showUnderConstruction(.notificationsDailyOffer)

        XCTAssertEqual(logOuts, 1)
        XCTAssertTrue(model.showsNotifications)
        XCTAssertTrue(model.showsLoyaltyCardDetail)
        XCTAssertFalse(model.showsLogOutConfirmation)
        XCTAssertEqual(model.underConstructionAction, .product)
        XCTAssertTrue(model.showsUnderConstructionAlert)

        model.dismissUnderConstruction()
        XCTAssertFalse(model.showsUnderConstructionAlert)
        XCTAssertNil(model.underConstructionAction)
        XCTAssertTrue(model.isLoggingOut)
        model.showUnderConstruction(.product)
        XCTAssertFalse(model.showsUnderConstructionAlert)

        let closed = HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            onLogOut: { logOuts += 1 }
        )
        closed.profileTapped()
        closed.confirmLogOut()
        closed.openNotifications()
        closed.openLoyaltyCardDetail()
        closed.showUnderConstruction(.challenge)
        XCTAssertEqual(logOuts, 2)
        XCTAssertFalse(closed.showsNotifications)
        XCTAssertFalse(closed.showsLoyaltyCardDetail)
        XCTAssertFalse(closed.showsUnderConstructionAlert)
        XCTAssertNil(closed.underConstructionAction)
    }

    func testNotificationsOpenAndClose() {
        let model = makeModel()
        XCTAssertFalse(model.showsNotifications)

        model.openNotifications()
        XCTAssertTrue(model.showsNotifications)
        model.openNotifications()
        XCTAssertTrue(model.showsNotifications)

        model.closeNotifications()
        XCTAssertFalse(model.showsNotifications)
        model.closeNotifications()
        XCTAssertFalse(model.showsNotifications)
        XCTAssertFalse(model.showsLoyaltyCardDetail)
        XCTAssertFalse(model.showsUnderConstructionAlert)
        XCTAssertFalse(model.isLoggingOut)
    }

    func testLoyaltyPopupOpensAndCloses() {
        let model = makeModel()
        XCTAssertFalse(model.showsLoyaltyCardDetail)

        model.openLoyaltyCardDetail()
        XCTAssertTrue(model.showsLoyaltyCardDetail)
        model.openLoyaltyCardDetail()
        XCTAssertTrue(model.showsLoyaltyCardDetail)

        model.closeLoyaltyCardDetail()
        XCTAssertFalse(model.showsLoyaltyCardDetail)
        model.closeLoyaltyCardDetail()
        XCTAssertFalse(model.showsLoyaltyCardDetail)
        XCTAssertFalse(model.showsNotifications)
        XCTAssertFalse(model.showsUnderConstructionAlert)
        XCTAssertFalse(model.isLoggingOut)
    }

    func testEachUnderConstructionActionShowsTheAlertAndDismissClearsIt() {
        let model = makeModel()
        XCTAssertEqual(
            HomeUnderConstructionAction.allCases.count,
            8,
            "Home wires one control to each under-construction entry point"
        )

        for action in HomeUnderConstructionAction.allCases {
            XCTAssertFalse(model.showsUnderConstructionAlert)
            XCTAssertNil(model.underConstructionAction)

            model.showUnderConstruction(action)

            XCTAssertTrue(model.showsUnderConstructionAlert, "\(action) did not show the alert")
            XCTAssertEqual(model.underConstructionAction, action)
            XCTAssertFalse(model.showsNotifications)
            XCTAssertFalse(model.showsLoyaltyCardDetail)
            XCTAssertFalse(model.showsLogOutConfirmation)
            XCTAssertFalse(model.isLoggingOut)

            model.dismissUnderConstruction()

            XCTAssertFalse(model.showsUnderConstructionAlert, "\(action) did not dismiss")
            XCTAssertNil(model.underConstructionAction)
        }
    }

    private func makeModel() -> HomeScreenModel {
        HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            onLogOut: {}
        )
    }
}

private struct ProfileLoadFailed: Error {}

private final class ScriptedProfileRepository: ProfileRepository {
    var results: [Result<ProfileData?, Error>]
    private(set) var fetchedUserIds: [String] = []

    init(results: [Result<ProfileData?, Error>]) {
        self.results = results
    }

    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}

    func updateName(userId: String, name: String) async throws {}

    func fetchProfile(userId: String) async throws -> ProfileData? {
        fetchedUserIds.append(userId)
        guard !results.isEmpty else { return nil }
        return try results.removeFirst().get()
    }
}
