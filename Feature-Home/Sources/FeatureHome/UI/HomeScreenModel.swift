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
    @Published private(set) var showsLogOutConfirmation = false
    @Published private(set) var showsLoyaltyCardDetail = false
    @Published private(set) var showsNotifications = false
    @Published private(set) var isLoggingOut = false
    @Published private(set) var showsUnderConstructionAlert = false
    private(set) var underConstructionAction: HomeUnderConstructionAction?

    private let userId: String
    private let profileRepository: ProfileRepository
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
        onLogOut: @escaping () -> Void
    ) {
        self.userId = userId
        self.profileRepository = profileRepository
        self.onLogOut = onLogOut
    }

    /// Trimmed profile name. A missing profile or any error, including
    /// cancellation, clears the name — the same `do/catch` the view had.
    func loadUserName() async {
        do {
            let profile = try await profileRepository.fetchProfile(userId: userId)
            userName = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            userName = ""
        }
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
