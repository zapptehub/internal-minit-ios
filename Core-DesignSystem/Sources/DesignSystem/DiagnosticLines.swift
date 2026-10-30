import SwiftUI
import UIKit

/// Optional line recorder. The app installs it for internal builds; a nil recorder drops the line.
public enum DiagnosticLines {
    public nonisolated(unsafe) static var record: (@Sendable (String) -> Void)?

    /// Set while a touch is being delivered, when this call already named that interaction.
    /// Route and field lines are not taps, so they leave the automatic tap hook free to log.
    nonisolated(unsafe) static var loggedTapDuringDelivery = false

    public static func line(_ text: String) {
        if record != nil, marksTap(text) {
            loggedTapDuringDelivery = true
        }
        record?(text)
    }

    public static func beginDelivery() {
        loggedTapDuringDelivery = false
    }

    public static func loggedTapDuringThisDelivery() -> Bool {
        loggedTapDuringDelivery
    }

    /// Screen lines such as `home.notifications` already name the control.
    /// `route`, `field`, and HTTP lines describe something else and must not hide a tap.
    private static func marksTap(_ text: String) -> Bool {
        if text.hasPrefix("route ") || text.hasPrefix("field ") { return false }
        let methods = ["GET ", "POST ", "PUT ", "PATCH ", "DELETE ", "HEAD "]
        if methods.contains(where: { text.hasPrefix($0) }) { return false }
        return true
    }
}

/// Stable names for taps the screen already knows, such as a tab id.
/// Localized titles are mapped back to those ids so the line does not follow the language.
public enum DiagnosticTaps {
    /// `tap tab.offers`. A value that is not a tab id becomes `tap tab`.
    public static func tab(_ rawValue: String) -> String {
        guard let id = stableID(rawValue) else { return "tap tab" }
        return "tap tab.\(id)"
    }

    /// `offers` from `offers` or `tab.offers`. Emails, ids, and other non-tab tokens are nil.
    public static func stableID(_ rawValue: String) -> String? {
        var id = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.hasPrefix("tab.") {
            id = String(id.dropFirst(4))
        }
        guard id.range(of: #"^[a-z][a-z0-9]{0,32}$"#, options: .regularExpression) != nil else { return nil }
        return id
    }

    /// Tab id for a localized bar title (`Ponuky` → `offers`). Unknown titles are nil.
    public static func tabID(matchingTitle title: String) -> String? {
        titles[fold(title)]
    }

    /// `route tab <id>` when nothing is touching the screen.
    /// A finger tap the hook already named stays silent here. A finger tap the hook could
    /// not name (`logsName: false`) is recorded as `tap tab.<id>` instead of a route.
    public static func logSelectionChange(_ rawValue: String) {
        let id = stableID(rawValue)
        if userTabTap {
            let hookLogs = hookWillLogTab
            _ = consumeUserTabTap()
            if !hookLogs, let id {
                DiagnosticLines.line("tap tab.\(id)")
            }
            return
        }
        guard let id else { return }
        DiagnosticLines.line("route tab \(id)")
    }

    /// The next selection change came from a tap on the tab bar.
    /// `logsName` means the touch hook will write `tap tab.<id>` itself.
    /// `endUserTabTurn` drops the flag after SwiftUI has handled that change, so a retap
    /// cannot swallow a later programmatic route.
    public static func noteUserTabTap(logsName: Bool = true) {
        userTabGeneration += 1
        userTabTap = true
        hookWillLogTab = logsName
    }

    /// The hook wrote `tap tab.<id>` after SwiftUI may already have queued `onChange`.
    /// A later selection callback for this same touch must not write it again.
    public static func claimTabTapLogged() {
        hookWillLogTab = true
    }

    public static func endUserTabTurn() {
        let generation = userTabGeneration
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                guard generation == userTabGeneration else { return }
                userTabTap = false
                hookWillLogTab = false
            }
        }
    }

    public static func consumeUserTabTap() -> Bool {
        let value = userTabTap
        userTabTap = false
        hookWillLogTab = false
        if value {
            userTabGeneration += 1
        }
        return value
    }

    public static func clearUserTabTap() {
        userTabTap = false
        hookWillLogTab = false
        userTabGeneration += 1
    }

    /// Stable token safe to store as an accessibility identifier and a tap anchor.
    /// Emails and strings with spaces are nil. The report hook still drops secrets.
    public static func safeTapID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^[A-Za-z][A-Za-z0-9._-]{0,80}$"#, options: .regularExpression) != nil else {
            return nil
        }
        if value.contains("@") { return nil }
        return value
    }

    nonisolated(unsafe) private static var userTabTap = false
    /// The touch hook has a `tab.<id>` and will record it. The selection callback must not.
    nonisolated(unsafe) private static var hookWillLogTab = false
    nonisolated(unsafe) private static var userTabGeneration = 0

    private static func fold(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }

    /// Folded `common.tabName.*` titles in en, sk, and hu.
    private static let titles: [String: String] = [
        "home": "home",
        "domov": "home",
        "kezdolap": "home",
        "offers": "offers",
        "ponuky": "offers",
        "ajanlatok": "offers",
        "map": "map",
        "mapa": "map",
        "terkep": "map",
        "card": "card",
        "karta": "card",
        "kartya": "card",
        "game": "game",
        "hra": "game",
        "jatek": "game",
    ]
}

/// Focus and first-edit lines for a single field. The text is never an argument: callers pass
/// only the field id, so a password, email, OTP, name, or card code cannot appear in the line.
public struct DiagnosticFieldState {
    public private(set) var didType = false

    public init() {}

    public mutating func focusChanged(id: String, isFocused: Bool) -> String? {
        didType = false
        guard isFocused else { return nil }
        return "field focused \(id)"
    }

    public mutating func textChanged(id: String, isFocused: Bool) -> String? {
        guard isFocused, !didType else { return nil }
        didType = true
        return "field typed \(id)"
    }
}

private struct DiagnosticFieldModifier: ViewModifier {
    let id: String?
    /// Observed so a keystroke can emit one `field typed` line. The characters are not recorded.
    let text: String
    let isFocused: Bool
    @State private var trace = DiagnosticFieldState()

    func body(content: Content) -> some View {
        content
            .onChange(of: isFocused) { _, focused in
                guard let id else { return }
                var next = trace
                let line = next.focusChanged(id: id, isFocused: focused)
                trace = next
                if let line {
                    DiagnosticLines.line(line)
                }
            }
            .onChange(of: text) { _, _ in
                guard let id else { return }
                var next = trace
                let line = next.textChanged(id: id, isFocused: isFocused)
                trace = next
                if let line {
                    DiagnosticLines.line(line)
                }
            }
    }
}

extension View {
    /// `field focused <id>` when focus begins, and `field typed <id>` once per focus.
    /// Pass `nil` for `id` to record nothing. `text` is only a change signal.
    public func diagnosticField(id: String?, text: String, isFocused: Bool) -> some View {
        modifier(DiagnosticFieldModifier(id: id, text: text, isFocused: isFocused))
    }

    /// Names a finger tap `tap <id>` from the touch hook. `id` is also the accessibility
    /// identifier. Nil and unsafe ids record nothing. A drag does not hit this as a tap.
    /// Screens that already call `DiagnosticLines.line` for the same control should not
    /// add this, or the touch would be written twice.
    public func diagnosticTap(_ id: String?) -> some View {
        modifier(DiagnosticTapModifier(id: id))
    }
}

/// Clear marker the size of the control. The touch hook reads `tapID` at the finger
/// because a SwiftUI `Button` is not a `UIControl` and its identifier is not on the hit view.
public final class DiagnosticTapAnchorView: UIView {
    public var tapID: String = ""
    private static let registry = NSHashTable<DiagnosticTapAnchorView>.weakObjects()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            Self.registry.remove(self)
        } else {
            Self.registry.add(self)
        }
    }

    /// Smallest anchor containing `point`. Nested controls beat the card around them.
    public static func bestID(at point: CGPoint, in window: UIWindow) -> String? {
        var best: (id: String, area: CGFloat)?
        for anchor in registry.allObjects {
            guard anchor.window === window, anchor.tapID.isEmpty == false else { continue }
            guard !isHiddenInHierarchy(anchor) else { continue }
            let frame = anchor.convert(anchor.bounds, to: window)
            guard frame.width > 1, frame.height > 1, frame.contains(point) else { continue }
            let area = frame.width * frame.height
            if best == nil || area < best!.area {
                best = (anchor.tapID, area)
            }
        }
        return best?.id
    }

    public static func installedView(id: String, in window: UIWindow) -> DiagnosticTapAnchorView? {
        registry.allObjects.first { anchor in
            anchor.window === window && anchor.tapID == id && anchor.bounds.width > 1 && anchor.bounds.height > 1
        }
    }

    private static func isHiddenInHierarchy(_ view: UIView) -> Bool {
        var node: UIView? = view
        while let current = node {
            if current.isHidden || current.alpha < 0.01 { return true }
            node = current.superview
        }
        return false
    }
}

private struct DiagnosticTapAnchor: UIViewRepresentable {
    var id: String

    func makeUIView(context: Context) -> DiagnosticTapAnchorView {
        let view = DiagnosticTapAnchorView()
        view.tapID = id
        return view
    }

    func updateUIView(_ view: DiagnosticTapAnchorView, context: Context) {
        view.tapID = id
    }
}

private struct DiagnosticTapModifier: ViewModifier {
    var id: String?

    func body(content: Content) -> some View {
        if let safe = DiagnosticTaps.safeTapID(id) {
            content
                .accessibilityIdentifier(safe)
                .background {
                    DiagnosticTapAnchor(id: safe)
                        .allowsHitTesting(false)
                }
        } else {
            content
        }
    }
}
