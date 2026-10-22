import Combine
import DataProfile
import Foundation

/// Which Home control shows the shared under-construction alert.
///
/// Each case is one entry point. The design-system lists used to keep this flag
/// in their own `@State`; Home now owns it so the same alert can be opened,
/// dismissed, and blocked while logging out without rendering the screen.
enum HomeUnderConstructionAction: CaseIterable {
    case dailyOfferBanner
    case product
    case productsSeeAll
    case challenge
    case challengesSeeAll
    case newsAndRecipe
    case newsAndRecipesSeeAll
    case notificationsDailyOffer
}

/// Home interaction state extracted from `HomeScreen`'s `@State`.
///
/// Profile loading, log-out confirmation, the notifications cover, the loyalty
/// popup, and the under-construction alert behave as they did in the view.
/// `.disabled(isLoggingOut)` still wraps the screen; these guards are the same
/// gate for calls that the disabled controls no longer deliver.
@MainActor
final class HomeScreenModel: ObservableObject {
    @Published private(set) var userName = ""
    /// Profile `avatarUrl`. Nil on the firebase backend, and nil again when the
    /// profile load fails. The header rewrites a `/v1/media/` path onto the API
    /// base, and fetches a same-origin URL outside that path as-is. A blank
    /// URL, a non-http scheme, a `.` or `..` path segment, and a foreign URL
    /// outside that path stay on the placeholder.
    @Published private(set) var avatarURL: String?
    /// Firebase sample until an HTTP catalog arrives. The sample stays here
    /// while a request is in flight, including a retry. A failed first load
    /// leaves it here and sets `showsHomeLoadFailure`, so the screen does not
    /// present the sample as a healthy Home. A failure after a successful
    /// load does not replace this catalog.
    @Published private(set) var catalog: HomeCatalog = .firebase
    /// The first HTTP load failed and no successful catalog is on screen.
    /// False for a firebase build, while a request is in flight, and after a
    /// successful load. The screen shows the failure and a retry instead of
    /// `catalog` while this is true.
    @Published private(set) var showsHomeLoadFailure = false
    @Published private(set) var showsLogOutConfirmation = false
    @Published private(set) var showsLoyaltyCardDetail = false
    @Published private(set) var showsNotifications = false
    @Published private(set) var isLoggingOut = false
    @Published private(set) var showsUnderConstructionAlert = false
    private(set) var underConstructionAction: HomeUnderConstructionAction?

    private let userId: String
    private let profileRepository: ProfileRepository
    private let homeRepository: any HomeRepository
    /// Latest log-out callback. The confirm button assigns the view's current
    /// closure before calling `confirmLogOut`, matching the old button body.
    var onLogOut: () -> Void
    /// Set when the confirmation alert opens. Cancel clears it. Confirm reads
    /// it so a system binding update that hides the alert first cannot drop
    /// the log-out.
    private var logOutConfirmationArmed = false
    /// True after `load()` has returned a catalog the screen should keep.
    /// A later failure does not replace that catalog or show the failure.
    private var hasLoadedCatalog = false
    /// Catalog load whose result may be published. A newer load bumps this
    /// and cancels `catalogLoadTask`, so a double tap cannot apply the older
    /// failure while the newer request is still running.
    private var catalogLoadID = 0
    private var catalogLoadTask: Task<Void, Never>?

    init(
        userId: String,
        profileRepository: ProfileRepository,
        homeRepository: any HomeRepository,
        onLogOut: @escaping () -> Void
    ) {
        self.userId = userId
        self.profileRepository = profileRepository
        self.homeRepository = homeRepository
        self.onLogOut = onLogOut
    }

    /// Profile name and the home catalog. The catalog starts as the firebase
    /// sample, so that face stays up while HTTP is in flight.
    func loadHome() async {
        async let profile: Void = loadUserName()
        async let home: Void = loadCatalog()
        _ = await (profile, home)
    }

    /// Trimmed profile name. A missing profile or a failed load clears the name
    /// and the avatar URL. Cancellation is not a failure: the name and avatar
    /// stay as they were. A firebase profile leaves the avatar nil.
    func loadUserName() async {
        do {
            let profile = try await profileRepository.fetchProfile(userId: userId)
            guard !Task.isCancelled else { return }
            userName = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            avatarURL = profile?.avatarUrl
        } catch {
            guard !isCancellation(error) else { return }
            userName = ""
            avatarURL = nil
        }
    }

    /// Runs one catalog load. A newer call cancels the in-flight task and
    /// retires its id, which drops a stale success or failure. Cancelling the
    /// current load is not a failure: a cancelled retry puts the failure back
    /// when it was showing. Logout drops the result. An equal catalog is not
    /// assigned again. There is no disk cache.
    func loadCatalog() async {
        guard !isLoggingOut else { return }
        catalogLoadID += 1
        let loadID = catalogLoadID
        catalogLoadTask?.cancel()
        let task = Task { await self.performCatalogLoad(loadID: loadID) }
        catalogLoadTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func performCatalogLoad(loadID: Int) async {
        guard loadID == catalogLoadID, !Task.isCancelled else { return }
        let failureWasVisible = showsHomeLoadFailure
        if failureWasVisible {
            showsHomeLoadFailure = false
        }
        do {
            let loaded = try await homeRepository.load()
            guard loadID == catalogLoadID else { return }
            guard !isLoggingOut else { return }
            guard !Task.isCancelled else {
                restoreHomeLoadFailure(failureWasVisible)
                return
            }
            if catalog != loaded {
                catalog = loaded
            }
            hasLoadedCatalog = true
            if showsHomeLoadFailure {
                showsHomeLoadFailure = false
            }
        } catch {
            guard loadID == catalogLoadID else { return }
            guard !isLoggingOut else { return }
            guard !isCancellation(error) else {
                restoreHomeLoadFailure(failureWasVisible)
                return
            }
            guard !hasLoadedCatalog else { return }
            showHomeLoadFailure()
        }
    }

    /// Puts the failure back when a retry is cancelled before a catalog arrives.
    private func restoreHomeLoadFailure(_ failureWasVisible: Bool) {
        guard failureWasVisible, !hasLoadedCatalog, !showsHomeLoadFailure else { return }
        showHomeLoadFailure()
    }

    /// The failure replaces the catalog. The bell's sample cover is closed
    /// with it, so a cover opened on the in-flight sample does not stay up.
    private func showHomeLoadFailure() {
        showsHomeLoadFailure = true
        if showsNotifications {
            showsNotifications = false
        }
    }

    /// `client.request` throws `CancellationError` or `URLError.cancelled` when
    /// the screen's `.task` is cancelled. Either one, or a task that is already
    /// cancelled when the error arrives, must not be reported as a failed load.
    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError || Task.isCancelled {
            return true
        }
        return (error as? URLError)?.code == .cancelled
    }

    func profileTapped() {
        guard !isLoggingOut else { return }
        logOutConfirmationArmed = true
        showsLogOutConfirmation = true
    }

    func dismissLogOutConfirmation() {
        guard !isLoggingOut else { return }
        logOutConfirmationArmed = false
        showsLogOutConfirmation = false
    }

    /// Hides the alert without disarming confirm. SwiftUI sets the binding to
    /// `false` before the button action; confirm still sees the armed flag.
    func hideLogOutConfirmation() {
        showsLogOutConfirmation = false
    }

    func confirmLogOut() {
        guard logOutConfirmationArmed, !isLoggingOut else { return }
        logOutConfirmationArmed = false
        showsLogOutConfirmation = false
        isLoggingOut = true
        onLogOut()
    }

    func openNotifications() {
        guard !isLoggingOut, !showsHomeLoadFailure else { return }
        showsNotifications = true
    }

    func closeNotifications() {
        guard !isLoggingOut else { return }
        showsNotifications = false
    }

    func openLoyaltyCardDetail() {
        guard !isLoggingOut else { return }
        showsLoyaltyCardDetail = true
    }

    func closeLoyaltyCardDetail() {
        guard !isLoggingOut else { return }
        showsLoyaltyCardDetail = false
    }

    func showUnderConstruction(_ action: HomeUnderConstructionAction) {
        guard !isLoggingOut else { return }
        underConstructionAction = action
        showsUnderConstructionAlert = true
    }

    func dismissUnderConstruction() {
        underConstructionAction = nil
        showsUnderConstructionAlert = false
    }
}
