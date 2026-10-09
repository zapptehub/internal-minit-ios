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
        onDismiss: @escaping () -> Void
    ) {
        self.horizontalPadding = horizontalPadding
        isContentEnabled = isEnabled
        self.onDismiss = onDismiss
        self.ownerID = ownerID
        withAnimation(.default) { self.content = content }
    }

    /// Clears the popup if `ownerID` still owns it (the presenter's binding went false).
    func clear(ownerID: UUID) {
        guard self.ownerID == ownerID else { return }
        self.ownerID = nil
        onDismiss = nil
        withAnimation(.default) { content = nil }
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

    var body: some View {
        ZStack {
            if isPresented {
                ZStack {
                    Color.black.opacity(DSPopupMetrics.scrimOpacity)
                        .onTapGesture { onDismiss() }

                    popupContent()
                        .padding(.horizontal, horizontalPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.default, value: isPresented)
    }
}
