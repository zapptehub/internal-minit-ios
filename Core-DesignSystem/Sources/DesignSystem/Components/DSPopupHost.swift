import SwiftUI

/// Root-level presenter for `dsPopup`. Install it with `.dsPopupHost()` on a view that
/// wraps the whole screen (e.g. the app's `TabView`), and every `dsPopup` below it is
/// drawn there: centred on the full screen, safe areas ignored, with the scrim covering
/// the tab bar too (Figma "AMP / My Card": card at y 236 on the 874 screen).
@MainActor
final class DSPopupHostModel: ObservableObject {
    @Published private(set) var content: AnyView?
    private(set) var horizontalPadding: CGFloat = 20
    /// The presenter's `isEnabled` (e.g. Home's `.disabled(isLoggingOut)`), which the hosted
    /// popup can't inherit because it's drawn outside the presenter's subtree.
    @Published private(set) var isContentEnabled = true
    private var onDismiss: (() -> Void)?
    /// Identifies the `dsPopup` that presented the current content, so a stale one
    /// can't clear another's popup.
    private(set) var ownerID: UUID?

    init() {}

    func present(
        _ content: AnyView,
        horizontalPadding: CGFloat,
        isEnabled: Bool = true,
        ownerID: UUID,
        reduceMotion: Bool = false,
        onDismiss: @escaping () -> Void
    ) {
        self.horizontalPadding = horizontalPadding
        isContentEnabled = isEnabled
        self.onDismiss = onDismiss
        self.ownerID = ownerID
        DSMotion.perform(reduceMotion: reduceMotion) { self.content = content }
    }

    /// Clears the popup if `ownerID` still owns it (the presenter's binding went false).
    func clear(ownerID: UUID, reduceMotion: Bool = false) {
        guard self.ownerID == ownerID else { return }
        self.ownerID = nil
        onDismiss = nil
        DSMotion.perform(reduceMotion: reduceMotion) { content = nil }
    }

    /// Scrim tap: tells the presenter, whose binding change then clears the popup.
    func dismiss() {
        guard isContentEnabled else { return }
        onDismiss?()
    }
}

private struct DSPopupHostKey: EnvironmentKey {
    static var defaultValue: DSPopupHostModel? { nil }
}

extension EnvironmentValues {
    var dsPopupHost: DSPopupHostModel? {
        get { self[DSPopupHostKey.self] }
        set { self[DSPopupHostKey.self] = newValue }
    }
}

private struct DSPopupHostModifier: ViewModifier {
    @StateObject private var model = DSPopupHostModel()

    func body(content: Content) -> some View {
        content
            // The popup is a sibling overlay. Hide the screen underneath so VoiceOver
            // cannot move into Home or the tab bar while it is presented.
            .accessibilityHidden(model.content != nil)
            .environment(\.dsPopupHost, model)
            .overlay {
                DSPopupLayer(
                    isPresented: model.content != nil,
                    horizontalPadding: model.horizontalPadding,
                    onDismiss: { model.dismiss() }
                ) {
                    model.content
                }
                // Locked presenter (logout): Close and the scrim do nothing.
                .disabled(!model.isContentEnabled)
            }
    }
}

public extension View {
    /// Draws every `dsPopup` presented below this view on top of it, full screen. Apply to
    /// the root that owns the tab bar so the popup's scrim covers it.
    func dsPopupHost() -> some View {
        modifier(DSPopupHostModifier())
    }
}

/// Scrim plus centred card. Fills the full screen (safe areas ignored), so the card is
/// centred on the screen, not on the safe area or a tab's content.
struct DSPopupLayer<PopupContent: View>: View {
    let isPresented: Bool
    let horizontalPadding: CGFloat
    let onDismiss: () -> Void
    @ViewBuilder let popupContent: () -> PopupContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isPresented {
                ZStack {
                    Color.black.opacity(DSPopupMetrics.scrimOpacity)
                        .onTapGesture { onDismiss() }
                        .accessibilityHidden(true)

                    popupContent()
                        .padding(.horizontal, horizontalPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                // Identity (not a faded insertion) so Reduce Motion shows the popup
                // fully visible instead of leaving it at the transition's start.
                .transition(DSMotion.animates(reduceMotion: reduceMotion) ? .opacity : .identity)
                .modifier(DSPopupModalModifier())
            }
        }
        .animation(DSMotion.animation(.default, reduceMotion: reduceMotion), value: isPresented)
    }
}

/// `.isModal` on the popup, plus `accessibilityViewIsModal` on an anchor we own.
/// SwiftUI resets that flag on hosting views it owns; the anchor keeps it.
private struct DSPopupModalModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .background {
                DSPopupModalAnchor()
                    .allowsHitTesting(false)
            }
    }
}

/// Modal flag for the popup, and accessibility-hides the screen beside the overlay.
///
/// The card is a set of accessibility elements on the hosting view, not a subview of
/// this anchor, so the flag can live here without swallowing the title, QR, or Close.
/// Siblings of the overlay branch are Home and the tab bar.
private struct DSPopupModalAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> DSPopupModalAnchorView {
        let view = DSPopupModalAnchorView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: DSPopupModalAnchorView, context: Context) {
        uiView.isUserInteractionEnabled = false
        uiView.backgroundColor = .clear
        uiView.applyModal()
    }
}

private final class DSPopupModalAnchorView: UIView {
    private var hiddenSiblings: [UIView] = []
    private var isApplying = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            restoreHiddenSiblings()
        } else {
            applyModal()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyModal()
    }

    deinit {
        restoreHiddenSiblings()
    }

    func applyModal() {
        guard window != nil, !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        // This view is ours, so the flag stays put. SwiftUI resets it on the hosting
        // views it owns. The block wins over the Bool if UIKit consults both.
        accessibilityViewIsModal = true
        accessibilityViewIsModalBlock = { true }

        // Highest ancestor that still has a sizable sibling: that sibling is the
        // screen (and, under a TabView, the tab bar). Hide it while the popup is up.
        var overlayBranch: UIView = self
        var view: UIView = self
        while let parent = view.superview, parent !== window {
            let hasScreenSibling = parent.subviews.contains { sibling in
                sibling !== view && sibling.bounds.width > 40 && sibling.bounds.height > 40
            }
            if hasScreenSibling {
                overlayBranch = view
            }
            view = parent
        }
        updateHiddenSiblings(of: overlayBranch)
    }

    private func updateHiddenSiblings(of modal: UIView?) {
        let desired: [UIView]
        if let modal, let parent = modal.superview {
            desired = parent.subviews.filter { $0 !== modal }
        } else {
            desired = []
        }
        let desiredIDs = desired.map(ObjectIdentifier.init)
        let hiddenIDs = hiddenSiblings.map(ObjectIdentifier.init)
        guard desiredIDs != hiddenIDs else { return }
        for sibling in hiddenSiblings where !desired.contains(where: { $0 === sibling }) {
            sibling.accessibilityElementsHidden = false
        }
        for sibling in desired where !sibling.accessibilityElementsHidden {
            sibling.accessibilityElementsHidden = true
        }
        hiddenSiblings = desired
    }

    private func restoreHiddenSiblings() {
        for sibling in hiddenSiblings {
            sibling.accessibilityElementsHidden = false
        }
        hiddenSiblings = []
    }
}
