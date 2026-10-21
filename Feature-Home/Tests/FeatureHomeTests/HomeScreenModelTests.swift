import CoreNetworking
import CoreNetworkingTestUtilities
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
            homeRepository: FirebaseHomeRepository(),
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
            homeRepository: FirebaseHomeRepository(),
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
            homeRepository: FirebaseHomeRepository(),
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
            homeRepository: FirebaseHomeRepository(),
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
            homeRepository: FirebaseHomeRepository(),
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

    func testProfileLoadPublishesTheAvatarURLAndClearsIt() async {
        let url = "https://api.minit.app/v1/media/avatars/default.webp"
        let repository = ScriptedProfileRepository(results: [
            .success(ProfileData(name: "Iveta", surname: "", email: "", avatarUrl: url)),
            .success(nil),
            .failure(ProfileLoadFailed()),
        ])
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: repository,
            homeRepository: FirebaseHomeRepository(),
            onLogOut: {}
        )

        await model.loadUserName()
        XCTAssertEqual(model.avatarURL, url)
        XCTAssertEqual(model.userName, "Iveta")

        await model.loadUserName()
        XCTAssertNil(model.avatarURL)
        XCTAssertEqual(model.userName, "")

        await model.loadUserName()
        XCTAssertNil(model.avatarURL)
        XCTAssertEqual(model.userName, "")
    }

    func testLoadHomePublishesTheTrimmedNameAndKeepsTheFirebaseCatalog() async {
        let repository = ScriptedProfileRepository(results: [
            .success(ProfileData(name: "  Iveta \n", surname: "Novak", email: "iveta@example.com")),
        ])
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: repository,
            homeRepository: FirebaseHomeRepository(),
            onLogOut: {}
        )

        await model.loadHome()

        XCTAssertEqual(model.userName, "Iveta")
        XCTAssertEqual(model.catalog, .firebase)
        XCTAssertNil(model.avatarURL)
        XCTAssertEqual(repository.fetchedUserIds, ["user-1"])
    }

    func testCancellationLeavesTheLoadedCatalogUntouched() async throws {
        let document = try JSONDecoder().decode(HomeDocument.self, from: ContractFixtures.bytes("home.json"))
        let pause = Pause(started: expectation(description: "cancelled home request paused"))
        let client = SequencedHomeClient(
            pause: pause,
            steps: [
                .init(result: .success(document), pauses: false),
                .init(result: .failure(NetworkError.statusCode(503, Data())), pauses: true),
                .init(result: .failure(CancellationError()), pauses: false),
                .init(result: .failure(URLError(.cancelled)), pauses: false),
                .init(result: .failure(NetworkError.statusCode(503, Data())), pauses: false),
            ]
        )
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            homeRepository: HttpHomeRepository(client: client),
            onLogOut: {}
        )

        await model.loadCatalog()
        let loaded = model.catalog
        XCTAssertNotEqual(loaded, .firebase)

        let task = Task { await model.loadCatalog() }
        defer { pause.resume() }
        await fulfillment(of: [pause.started], timeout: 2)
        task.cancel()
        pause.resume()
        await task.value
        XCTAssertEqual(model.catalog, loaded)

        await model.loadCatalog()
        XCTAssertEqual(model.catalog, loaded)
        await model.loadCatalog()
        XCTAssertEqual(model.catalog, loaded)

        await model.loadCatalog()
        XCTAssertEqual(model.catalog, .firebase)
    }

    func testCancellationLeavesTheNameAndAvatarUntouched() async {
        let url = "https://api.minit.app/v1/media/avatars/default.webp"
        let pause = Pause(started: expectation(description: "cancelled profile request paused"))
        let repository = SequencedProfileRepository(
            pause: pause,
            steps: [
                .init(
                    result: .success(ProfileData(name: "Iveta", surname: "", email: "", avatarUrl: url)),
                    pauses: false
                ),
                .init(result: .failure(ProfileLoadFailed()), pauses: true),
                .init(result: .failure(CancellationError()), pauses: false),
                .init(result: .failure(URLError(.cancelled)), pauses: false),
                .init(result: .failure(ProfileLoadFailed()), pauses: false),
            ]
        )
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: repository,
            homeRepository: FirebaseHomeRepository(),
            onLogOut: {}
        )

        await model.loadUserName()
        XCTAssertEqual(model.userName, "Iveta")
        XCTAssertEqual(model.avatarURL, url)

        let task = Task { await model.loadUserName() }
        defer { pause.resume() }
        await fulfillment(of: [pause.started], timeout: 2)
        task.cancel()
        pause.resume()
        await task.value
        XCTAssertEqual(model.userName, "Iveta")
        XCTAssertEqual(model.avatarURL, url)

        await model.loadUserName()
        XCTAssertEqual(model.userName, "Iveta")
        XCTAssertEqual(model.avatarURL, url)
        await model.loadUserName()
        XCTAssertEqual(model.userName, "Iveta")
        XCTAssertEqual(model.avatarURL, url)

        await model.loadUserName()
        XCTAssertEqual(model.userName, "")
        XCTAssertNil(model.avatarURL)
    }

    func testCatalogStaysOnTheFirebaseSampleWhileHTTPIsInFlightAndAfterFailure() async throws {
        let document = try JSONDecoder().decode(HomeDocument.self, from: ContractFixtures.bytes("home.json"))
        let pause = Pause(started: expectation(description: "home request paused"))
        let client = PausingHomeClient(pause: pause, result: .success(document))
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            homeRepository: HttpHomeRepository(client: client),
            onLogOut: {}
        )

        let task = Task { await model.loadCatalog() }
        await fulfillment(of: [pause.started], timeout: 2)
        XCTAssertEqual(model.catalog, .firebase)
        pause.resume()
        await task.value

        XCTAssertEqual(client.paths, ["/v1/home"])
        XCTAssertEqual(client.methods, [.GET])
        XCTAssertTrue(client.dataURLs.isEmpty)
        XCTAssertEqual(model.catalog.products.count, 10)
        XCTAssertNotEqual(model.catalog, .firebase)

        let failing = HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            homeRepository: HttpHomeRepository(client: ThrowingHomeClient()),
            onLogOut: {}
        )
        await failing.loadCatalog()
        XCTAssertEqual(failing.catalog, .firebase)
        XCTAssertFalse(failing.showsUnderConstructionAlert)
    }

    func testCatalogResultAfterLogOutIsDropped() async throws {
        let document = try JSONDecoder().decode(HomeDocument.self, from: ContractFixtures.bytes("home.json"))
        let pause = Pause(started: expectation(description: "home request paused"))
        let client = PausingHomeClient(pause: pause, result: .success(document))
        let model = HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            homeRepository: HttpHomeRepository(client: client),
            onLogOut: {}
        )
        let task = Task { await model.loadCatalog() }
        await fulfillment(of: [pause.started], timeout: 2)
        model.profileTapped()
        model.confirmLogOut()
        pause.resume()
        await task.value
        XCTAssertTrue(model.isLoggingOut)
        XCTAssertEqual(model.catalog, .firebase)
    }

    private func makeModel() -> HomeScreenModel {
        HomeScreenModel(
            userId: "user-1",
            profileRepository: ScriptedProfileRepository(results: []),
            homeRepository: FirebaseHomeRepository(),
            onLogOut: {}
        )
    }
}

private struct ProfileLoadFailed: Error {}

private final class Pause: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var resumed = false
    let started: XCTestExpectation

    init(started: XCTestExpectation) {
        self.started = started
    }

    func pause() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if resumed {
                lock.unlock()
                continuation.resume()
                return
            }
            self.continuation = continuation
            lock.unlock()
            started.fulfill()
        }
    }

    func resume() {
        lock.lock()
        resumed = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}

private enum ScriptedHomeResult {
    case success(HomeDocument)
    case failure(Error)
}

private final class PausingHomeClient: NetworkClient, @unchecked Sendable {
    let pause: Pause
    let result: ScriptedHomeResult
    private(set) var paths: [String] = []
    private(set) var methods: [HTTPMethod] = []
    private(set) var dataURLs: [URL] = []

    init(pause: Pause, result: ScriptedHomeResult) {
        self.pause = pause
        self.result = result
    }

    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        paths.append(path)
        methods.append(method)
        await pause.pause()
        switch result {
        case .failure(let error):
            throw error
        case .success(let document):
            guard let typed = document as? T else { throw NetworkError.invalidResponse }
            return typed
        }
    }

    func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: B
    ) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ url: URL) async throws -> Data {
        dataURLs.append(url)
        throw NetworkError.invalidURL
    }
}

private struct SequencedHomeStep {
    var result: ScriptedHomeResult
    var pauses: Bool
}

private final class SequencedHomeClient: NetworkClient, @unchecked Sendable {
    let pause: Pause
    private var steps: [SequencedHomeStep]
    private var index = 0
    private let lock = NSLock()

    init(pause: Pause, steps: [SequencedHomeStep]) {
        self.pause = pause
        self.steps = steps
    }

    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        let step = nextStep()
        if step.pauses {
            await pause.pause()
        }
        switch step.result {
        case .failure(let error):
            throw error
        case .success(let document):
            guard let typed = document as? T else { throw NetworkError.invalidResponse }
            return typed
        }
    }

    func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: B
    ) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ url: URL) async throws -> Data {
        throw NetworkError.invalidURL
    }

    private func nextStep() -> SequencedHomeStep {
        lock.lock()
        defer { lock.unlock() }
        let step = steps[index]
        index += 1
        return step
    }
}

private struct SequencedProfileStep {
    var result: Result<ProfileData?, Error>
    var pauses: Bool
}

private final class SequencedProfileRepository: ProfileRepository, @unchecked Sendable {
    let pause: Pause
    private var steps: [SequencedProfileStep]
    private var index = 0
    private let lock = NSLock()

    init(pause: Pause, steps: [SequencedProfileStep]) {
        self.pause = pause
        self.steps = steps
    }

    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}

    func updateName(userId: String, name: String) async throws {}

    func fetchProfile(userId: String) async throws -> ProfileData? {
        let step: SequencedProfileStep
        lock.lock()
        step = steps[index]
        index += 1
        lock.unlock()
        if step.pauses {
            await pause.pause()
        }
        return try step.result.get()
    }
}

private final class ThrowingHomeClient: NetworkClient, @unchecked Sendable {
    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        throw NetworkError.statusCode(503, Data())
    }

    func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: B
    ) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ url: URL) async throws -> Data {
        throw NetworkError.invalidURL
    }
}

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
