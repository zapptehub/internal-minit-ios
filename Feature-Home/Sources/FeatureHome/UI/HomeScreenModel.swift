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
    /// load does not replace this catalog. A failed pull sets
    /// `showsRefreshError` and leaves this catalog on screen.
    @Published private(set) var catalog: HomeCatalog = .firebase
    /// The first HTTP load failed and no successful catalog is on screen.
    /// False for a firebase build, while a request is in flight, and after a
    /// successful load. The screen shows the failure and a retry instead of
    /// `catalog` while this is true. A pull that fails after a successful
    /// load leaves this false.
    @Published private(set) var showsHomeLoadFailure = false
    /// True while a pull-to-refresh is waiting on a home load, including a
    /// pull that joined a load already running. Initial load and Retry leave
    /// it false. The system refresh indicator is driven by `.refreshable`;
    /// this flag is the same interval for tests and for logout.
    @Published private(set) var isRefreshing = false
    /// A pull failed after a catalog was already on screen. The catalog stays,
    /// and the screen shows a transient message instead of the first-load failure.
    @Published private(set) var showsRefreshError = false
    /// Bumps on every pull failure that sets `showsRefreshError`, so a second
    /// failure can present the message again while the flag is already true.
    @Published private(set) var refreshErrorGeneration = 0
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
    /// A later failure does not replace that catalog or show the first-load
    /// failure. A pull failure sets `showsRefreshError` instead.
    private var hasLoadedCatalog = false
    /// A retry set this when it hid the failure. It stays set until that
    /// generation of loads publishes a catalog or a real failure. Cancelling
    /// the current load restores the failure from this flag, including when
    /// an overlapping retry already saw `showsHomeLoadFailure` as false.
    private var homeLoadFailureHiddenForRetry = false
    /// Catalog load whose result may be published. A newer load bumps this
    /// and cancels `catalogLoadTask`, so a double tap cannot apply the older
    /// failure while the newer request is still running.
    private var catalogLoadID = 0
    /// Cleared at the end of that load, before the task is complete, so a
    /// pull cannot join a load that has already finished.
    private var catalogLoadTask: Task<Void, Never>?
    /// Pulls waiting on a home load. A failure while this is positive is a
    /// pull failure, including when the pull joined a load Retry later
    /// replaced. The indicator stays up until the last waiter leaves.
    private var pullWaiters = 0

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
    /// when a retry had hidden it. A second retry starts after that hide, so
    /// it must not treat `showsHomeLoadFailure == false` as "nothing to
    /// restore". Logout drops the result. An equal catalog is not assigned
    /// again. There is no disk cache. Pull-to-refresh does not call this while
    /// a load is already running.
    func loadCatalog() async {
        await loadCatalog(origin: .initialOrRetry)
    }

    /// Reloads the home document from a pull.
    ///
    /// Joins a load that is already running and does not call `load()` again.
    /// Does not cancel that load. If Retry replaces the joined load, this
    /// waits for the replacement as well, and the indicator stays up until
    /// that load is idle. A finished load is not treated as something to
    /// join. Retry still goes through `loadCatalog()` and may cancel. A
    /// failure after a catalog is on screen keeps the catalog and sets
    /// `showsRefreshError`, including when this pull only joined the load.
    /// A failure with nothing loaded shows the first-load failure and leaves
    /// the refresh message clear. Profile is not loaded again.
    func refreshFromPull() async {
        guard !isLoggingOut else { return }
        pullWaiters += 1
        isRefreshing = true
        defer {
            pullWaiters -= 1
            if pullWaiters == 0 {
                isRefreshing = false
            }
        }
        if showsRefreshError {
            showsRefreshError = false
        }
        while !isLoggingOut, !Task.isCancelled {
            if let existing = catalogLoadTask {
                let joinedID = catalogLoadID
                await existing.value
                if isLoggingOut || Task.isCancelled { return }
                if catalogLoadTask != nil, catalogLoadID != joinedID {
                    continue
                }
                return
            }
            await loadCatalog(origin: .pull)
            if isLoggingOut || Task.isCancelled { return }
            if catalogLoadTask != nil {
                continue
            }
            return
        }
    }

    /// Clears the transient pull-failure message. The generation stays so the
    /// next failure still changes it.
    func dismissRefreshError() {
        showsRefreshError = false
    }

    private enum CatalogLoadOrigin {
        case initialOrRetry
        case pull
    }

    private func loadCatalog(origin: CatalogLoadOrigin) async {
        guard !isLoggingOut else { return }
        catalogLoadID += 1
        let loadID = catalogLoadID
        catalogLoadTask?.cancel()
        let task = Task { await self.performCatalogLoad(loadID: loadID, origin: origin) }
        catalogLoadTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        if catalogLoadID == loadID {
            catalogLoadTask = nil
        }
    }

    private func performCatalogLoad(loadID: Int, origin: CatalogLoadOrigin) async {
        // Nil the task before it completes. A pull that runs after this load
        // has finished must start its own load, not join this one.
        defer {
            if catalogLoadID == loadID {
                catalogLoadTask = nil
            }
        }
        // A superseded load must not restore or clear the flag. The current
        // id owns that, so a cancelled older retry cannot drop the failure
        // the newer retry is still responsible for.
        guard loadID == catalogLoadID else { return }
        if Task.isCancelled {
            restoreHiddenHomeLoadFailure()
            return
        }
        // Pull keeps the first-load failure on screen until this load ends.
        // Retry hides it at the start so the sample shows while the request runs.
        if origin == .initialOrRetry, showsHomeLoadFailure {
            showsHomeLoadFailure = false
            homeLoadFailureHiddenForRetry = true
        }
        do {
            let loaded = try await homeRepository.load()
            guard loadID == catalogLoadID else { return }
            guard !isLoggingOut else { return }
            guard !Task.isCancelled else {
                restoreHiddenHomeLoadFailure()
                return
            }
            if catalog != loaded {
                catalog = loaded
            }
            hasLoadedCatalog = true
            homeLoadFailureHiddenForRetry = false
            if showsHomeLoadFailure {
                showsHomeLoadFailure = false
            }
            if showsRefreshError {
                showsRefreshError = false
            }
        } catch {
            guard loadID == catalogLoadID else { return }
            guard !isLoggingOut else { return }
            guard !isCancellation(error) else {
                restoreHiddenHomeLoadFailure()
                return
            }
            homeLoadFailureHiddenForRetry = false
            guard !hasLoadedCatalog else {
                if origin == .pull || pullWaiters > 0 {
                    showsRefreshError = true
                    refreshErrorGeneration += 1
                }
                return
            }
            showHomeLoadFailure()
        }
    }

    /// Puts the failure back when the current retry is cancelled before a
    /// catalog arrives. No-op for a first load, a load that already kept a
    /// catalog, and logout.
    private func restoreHiddenHomeLoadFailure() {
        guard homeLoadFailureHiddenForRetry, !hasLoadedCatalog, !isLoggingOut else { return }
        homeLoadFailureHiddenForRetry = false
        if !showsHomeLoadFailure {
            showHomeLoadFailure()
        }
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
        isRefreshing = false
        showsRefreshError = false
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
