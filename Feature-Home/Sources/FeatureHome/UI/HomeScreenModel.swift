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
    /// profile load fails. The header loads bytes only when this is a URL on the
    /// API origin.
    @Published private(set) var avatarURL: String?
    /// Firebase sample until an HTTP catalog arrives. A failed load puts the sample back.
    @Published private(set) var catalog: HomeCatalog = .firebase
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

    /// HTTP replaces the sample only after a successful decode. A failure, and a
    /// result that arrives after log-out has started, leaves the sample in place.
    /// Cancellation leaves the catalog already on screen. An equal value is not
    /// assigned again, so a firebase load does not publish a second time.
    /// There is no error screen and no disk cache.
    func loadCatalog() async {
        do {
            let loaded = try await homeRepository.load()
            guard !isLoggingOut, !Task.isCancelled else { return }
            if catalog != loaded {
                catalog = loaded
            }
        } catch {
            guard !isLoggingOut, !isCancellation(error) else { return }
            if catalog != .firebase {
                catalog = .firebase
            }
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
        guard !isLoggingOut else { return }
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
