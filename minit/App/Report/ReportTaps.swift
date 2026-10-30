#if MINIT_SHAKE
import DesignSystem
import UIKit

/// What the finger hit, without the text the person typed.
nonisolated struct ShakeReportTapTarget: Equatable {
    var identifier: String? = nil
    var label: String? = nil
    var role: ShakeReportTapRole = .control
    var inSheet = false
    var isTextInput = false
    var isKeyboard = false
    var interactive = false
}

nonisolated enum ShakeReportTapRole: Equatable {
    case button
    case tab
    case back
    case row
    case card
    case toggle
    case alert
    case field
    case control
}

/// Turns a hit into `tab.offers`, `back`, `field.email`, `alert.report`, or a generic role.
/// The caller prefixes `tap `. Names come from identifiers, then an allow-list of chrome labels.
/// Typed text, row and card contents, emails, phones, tokens, and ids are left out.
nonisolated enum ShakeReportTapNaming {
    static func name(for target: ShakeReportTapTarget) -> String? {
        if target.isKeyboard || !target.interactive { return nil }
        if target.isTextInput || target.role == .field {
            if let id = safeIdentifier(target.identifier) {
                return id == "field" || id.hasPrefix("field.") ? id : "field.\(id)"
            }
            return "field"
        }
        if isBackLabel(target.identifier) { return "back" }
        if safeIdentifier(target.identifier) == "close" { return "close" }
        switch target.role {
        case .back:
            return "back"
        case .tab:
            return tabName(target)
        case .alert:
            return contextual("alert", target, allowLabel: true)
        case .toggle:
            return contextual("toggle", target, allowLabel: true)
        case .row:
            return contextual("row", target, allowLabel: false)
        case .card:
            return contextual("card", target, allowLabel: false)
        case .field:
            return "field"
        case .button:
            if isBackLabel(target.label) || isBackLabel(target.identifier) {
                return "back"
            }
            if target.inSheet {
                return contextual("sheet", target, allowLabel: true)
            }
            return contextual("button", target, allowLabel: true)
        case .control:
            if isBackLabel(target.label) { return "back" }
            if target.inSheet {
                return contextual("sheet", target, allowLabel: true)
            }
            return contextual("control", target, allowLabel: false)
        }
    }

    static func isBackLabel(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered == "back" || lowered == "backbutton" || lowered.hasSuffix(".back") { return true }
        guard let token = controlToken(from: raw) else { return false }
        return token == "back" || token == "spat" || token == "vissza"
    }

    static func safeIdentifier(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^[A-Za-z][A-Za-z0-9._-]{0,80}$"#, options: .regularExpression) != nil else {
            return nil
        }
        if looksLikeSecret(value) || looksLikeOpaqueID(value) || isUIKitTypeName(value) { return nil }
        return value
    }

    /// Accessibility automation names a view after its class (`UIView`). That is not an app id.
    private static func isUIKitTypeName(_ value: String) -> Bool {
        value.range(of: #"^_?UI[A-Z][A-Za-z0-9]*$"#, options: .regularExpression) != nil
    }

    /// Short chrome label (`Send`, `Späť`) as `send` / `spat`. Anything outside the allow-list is nil.
    static func controlToken(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(trimmed.count) else { return nil }
        if trimmed.contains("@") || trimmed.contains("\n") || trimmed.contains("://") { return nil }
        if looksLikeSecret(trimmed) || looksLikeOpaqueID(trimmed) { return nil }
        let folded = trimmed
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var slug = ""
        var pendingDot = false
        for scalar in folded.unicodeScalars {
            if scalar.value < 128, CharacterSet.alphanumerics.contains(scalar) {
                if pendingDot, !slug.isEmpty { slug.append(".") }
                pendingDot = false
                slug.unicodeScalars.append(scalar)
            } else if !slug.isEmpty {
                pendingDot = true
            }
        }
        guard !slug.isEmpty, slug.count <= 40 else { return nil }
        if looksLikeSecret(slug) || looksLikeOpaqueID(slug) { return nil }
        return slug
    }

    private static func tabName(_ target: ShakeReportTapTarget) -> String {
        if let id = target.identifier, let stable = DiagnosticTaps.stableID(id) {
            return "tab.\(stable)"
        }
        if let label = target.label, let mapped = DiagnosticTaps.tabID(matchingTitle: label) {
            return "tab.\(mapped)"
        }
        return "tab"
    }

    private static func contextual(_ role: String, _ target: ShakeReportTapTarget, allowLabel: Bool) -> String {
        if let id = safeIdentifier(target.identifier) {
            if id == role || id.hasPrefix(role + ".") { return id }
            if id.contains(".") { return id }
            return "\(role).\(id)"
        }
        if allowLabel, let token = allowedLabelToken(from: target.label) {
            if token == role { return role }
            return "\(role).\(token)"
        }
        return role
    }

    /// Chrome words in en, sk, and hu. A person's name, an alert message, or any other
    /// free string is not a token, so the line stays `button` or `alert`.
    private static func allowedLabelToken(from raw: String?) -> String? {
        guard let token = controlToken(from: raw), allowedControlTokens.contains(token) else { return nil }
        return token
    }

    private static let allowedControlTokens: Set<String> = [
        "ok", "done", "cancel", "close", "back", "send", "retry", "report",
        "continue", "confirm", "delete", "save", "edit", "yes", "no", "skip",
        "next", "dismiss",
        "hotovo", "zrusit", "megse", "spat", "vissza", "odoslat", "kuldes",
        "pokracovat", "folytatas", "nahlasit", "bejelentes", "zavriet", "bezaras",
        "kesz", "ano", "nie", "igen", "nem",
    ]

    private static func looksLikeSecret(_ value: String) -> Bool {
        if value.contains("@") || value.contains("://") { return true }
        if value.range(
            of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#,
            options: .regularExpression
        ) != nil { return true }
        if value.range(of: #"\d{6,}"#, options: .regularExpression) != nil { return true }
        if value.filter(\.isNumber).count >= 7 { return true }
        if value.range(
            of: #"^[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}$"#,
            options: .regularExpression
        ) != nil { return true }
        if value.range(of: #"^[A-Za-z0-9_-]{20,}$"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// `uid-full-123` and `MINIT-CONTRACT1`: a separator plus a digit, and no spaces.
    private static func looksLikeOpaqueID(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace) else { return false }
        let digits = trimmed.filter(\.isNumber).count
        let separated = trimmed.contains("-") || trimmed.contains("_")
        if separated && digits >= 1 && trimmed.count >= 8 { return true }
        if trimmed.range(of: #"^[0-9a-fA-F]{16,}$"#, options: .regularExpression) != nil { return true }
        return false
    }
}

/// Reads a UIKit hit. Does not read `text`, `accessibilityValue`, or keyboard keys.
enum ShakeReportTapCapture {
    static let tapSlop: CGFloat = 10

    static func target(for view: UIView, window: UIWindow? = nil) -> ShakeReportTapTarget {
        var target = ShakeReportTapTarget()
        let host = window ?? view.window
        if let host, isKeyboardWindow(host) {
            target.isKeyboard = true
            return target
        }

        var current: UIView? = view
        while let node = current {
            let className = NSStringFromClass(type(of: node))
            if isKeyboardClass(className) || node.accessibilityTraits.contains(.keyboardKey) {
                target.isKeyboard = true
                return target
            }
            if isTextInput(node, className: className) {
                target.isTextInput = true
                target.interactive = true
                target.role = .field
                target.label = nil
                if target.identifier == nil,
                   let id = node.accessibilityIdentifier,
                   ShakeReportTapNaming.safeIdentifier(id) != nil {
                    target.identifier = id
                }
                current = node.superview
                continue
            }

            if target.identifier == nil,
               let id = node.accessibilityIdentifier,
               ShakeReportTapNaming.safeIdentifier(id) != nil {
                target.identifier = id
            }
            if target.label == nil {
                if let label = node.accessibilityLabel, !label.isEmpty {
                    target.label = label
                } else if let button = node as? UIButton, let title = button.currentTitle, !title.isEmpty {
                    target.label = title
                }
            }
            if isInteractive(node, className: className) {
                target.interactive = true
            }
            if let role = role(of: node, className: className), rank(role) > rank(target.role) {
                target.role = role
            }
            current = node.superview
        }

        if target.isTextInput {
            target.role = .field
            target.label = nil
        } else if isAlert(view) {
            target.role = .alert
            target.interactive = true
        } else if isBack(view, identifier: target.identifier, label: target.label) {
            target.role = .back
            target.interactive = true
            target.label = nil
        } else if ShakeReportTapNaming.safeIdentifier(target.identifier) == "close" {
            target.interactive = true
        }
        target.inSheet = isSheet(view)
        return target
    }

    static func isStationary(moved: CGFloat, tapCount: Int) -> Bool {
        tapCount >= 1 && moved < tapSlop
    }

    static func isKeyboardWindow(_ window: UIWindow) -> Bool {
        isKeyboardClass(NSStringFromClass(type(of: window)))
    }

    /// UIKit keyboard windows only. A SwiftUI hosting view whose type name contains
    /// "Keyboard" is not a keyboard, and must not swallow the taps under it.
    static func isKeyboardClass(_ name: String) -> Bool {
        name.hasPrefix("UIKeyboard")
            || name.hasPrefix("_UIKeyboard")
            || name.hasPrefix("_UIRemoteKeyboard")
            || name.hasPrefix("UIRemoteKeyboard")
            || name.hasPrefix("UITextEffectsWindow")
    }

    /// SwiftUI's hosting view, not every Swift class. Swift class names start with `_Tt`,
    /// and the tab host's mangled name also contains `Button` and `Toggle`.
    static func isSwiftUIHostingClass(_ name: String) -> Bool {
        name.contains("Hosting") || name.contains("SwiftUI")
    }

    /// The tab button itself. Wrapper views inside it also contain `_UITabButton` in the mangled name.
    static func isTabButtonClass(_ name: String) -> Bool {
        name == "_UITabButton"
            || name == "UITabBarButton"
            || name.hasSuffix("._UITabButton")
            || name.hasSuffix(".UITabBarButton")
    }

    private static func isTextInput(_ view: UIView, className: String) -> Bool {
        if view is UITextField || view is UITextView || view is UISearchBar { return true }
        if isSwiftUIHostingClass(className) { return false }
        if className.contains("TextField") || className.contains("TextView") || className.contains("FieldEditor") {
            return true
        }
        return view is UITextInput && !(view is UIButton)
    }

    private static func isInteractive(_ view: UIView, className: String) -> Bool {
        if view is UIControl { return true }
        if view.accessibilityTraits.contains(.button) || view.accessibilityTraits.contains(.link) { return true }
        if view.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer && $0.isEnabled }) == true {
            return true
        }
        if view is UITableViewCell || view is UICollectionViewCell { return true }
        if isSwiftUIHostingClass(className) { return false }
        if className.contains("Button") || className.contains("Switch") || className.contains("Toggle") {
            return true
        }
        return false
    }

    private static func role(of view: UIView, className: String) -> ShakeReportTapRole? {
        if view is UISwitch { return .toggle }
        if view is UITabBar { return .tab }
        if !isSwiftUIHostingClass(className),
           className.contains("Card") || className.contains("Carousel") || className.contains("Banner") {
            return .card
        }
        if view is UITableViewCell || view is UICollectionViewCell { return .row }
        if view is UIButton { return .button }
        // SwiftUI puts the button trait on the hosting view. That view is still a button.
        if view.accessibilityTraits.contains(.button) { return .button }
        if isSwiftUIHostingClass(className) { return nil }
        if isTabButtonClass(className) || className.contains("TabBar") {
            return .tab
        }
        if className.contains("Switch") || className.contains("Toggle") { return .toggle }
        if className.contains("Button") { return .button }
        return nil
    }

    /// Ancestors win when they are more specific: a button inside a tab bar is a tab,
    /// a button inside a row is a row, and a text field stays a field.
    private static func rank(_ role: ShakeReportTapRole) -> Int {
        switch role {
        case .control: return 0
        case .button: return 1
        case .row, .card: return 2
        case .toggle: return 3
        case .back, .alert, .tab: return 4
        case .field: return 5
        }
    }

    private static func isAlert(_ view: UIView) -> Bool {
        var responder: UIResponder? = view
        while let current = responder {
            if current is UIAlertController { return true }
            responder = current.next
        }
        return false
    }

    private static func isSheet(_ view: UIView) -> Bool {
        var responder: UIResponder? = view
        while let current = responder {
            if current is UIAlertController { return false }
            if let controller = current as? UIViewController, isSheetController(controller) { return true }
            responder = current.next
        }
        return false
    }

    /// iOS 27's default `modalPresentationStyle` is form sheet for every controller, including
    /// a window's root. A sheet is a controller that is actually presented as one.
    private static func isSheetController(_ controller: UIViewController) -> Bool {
        guard controller.presentingViewController != nil else { return false }
        switch controller.modalPresentationStyle {
        case .pageSheet, .formSheet, .automatic:
            return true
        default:
            return false
        }
    }

    private static func isBack(_ view: UIView, identifier: String?, label: String?) -> Bool {
        if ShakeReportTapNaming.isBackLabel(label) || ShakeReportTapNaming.isBackLabel(identifier) { return true }
        guard let nav = navigationController(from: view) else { return false }
        let showsBack = nav.viewControllers.count > 1 || nav.navigationBar.backItem != nil
        guard showsBack else { return false }
        return isLeadingNavigationButton(view)
    }

    /// The system back button's label is often the previous title. That title is dropped,
    /// and only a leading control on a stack that can pop (or a visible system back item) counts.
    private static func isLeadingNavigationButton(_ view: UIView) -> Bool {
        guard let bar = ancestor(UINavigationBar.self, from: view) else { return false }
        var node: UIView? = view
        while let current = node, current !== bar {
            let className = NSStringFromClass(type(of: current))
            if current is UIButton || className.contains("Button") {
                guard bar.bounds.width > 1 else { return false }
                let center = current.convert(CGPoint(x: current.bounds.midX, y: current.bounds.midY), to: bar)
                let onLeading = current.effectiveUserInterfaceLayoutDirection == .rightToLeft
                    ? center.x >= bar.bounds.midX
                    : center.x <= bar.bounds.midX
                if onLeading { return true }
            }
            node = current.superview
        }
        return false
    }

    static func navigationController(from view: UIView) -> UINavigationController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let nav = current as? UINavigationController { return nav }
            responder = current.next
        }
        return nil
    }

    static func ancestor<T: UIView>(_ type: T.Type, from view: UIView) -> T? {
        var node: UIView? = view
        while let current = node {
            if let match = current as? T { return match }
            node = current.superview
        }
        return nil
    }
}

struct ShakeReportHit {
    var view: UIView
    var point: CGPoint
    /// The anchor under the finger before the control's action runs. Close removes
    /// its anchor during the touch, so the id has to be captured first.
    var anchorID: String?
}

struct ShakeReportDelivery {
    var tabName: String?
    var switchesTab = false
    var hits: [ShakeReportHit] = []

    var hasWork: Bool { tabName != nil || !hits.isEmpty }
}

enum ShakeReportTouches {
    private struct Track {
        var start: CGPoint
        var moved: CGFloat
    }

    /// Set when this touch already logged `tap back`, so the back button is not logged again.
    private static var loggedBack = false
    private static var insideDepth = 0
    private static var interactiveArmed = false
    private static var lastBackTime: TimeInterval = -.infinity
    private static var loggedNames: Set<String> = []
    private static var tracks: [ObjectIdentifier: Track] = [:]

    static var isInsideTouch: Bool { insideDepth > 0 }

    static func resetForTests() {
        tracks.removeAll()
        loggedNames.removeAll()
        loggedBack = false
        insideDepth = 0
        interactiveArmed = false
        lastBackTime = -.infinity
        DiagnosticLines.beginDelivery()
        DiagnosticTaps.clearUserTabTap()
    }

    static func beginDelivery() {
        insideDepth += 1
        if insideDepth == 1 {
            DiagnosticLines.beginDelivery()
            loggedBack = false
            loggedNames.removeAll()
        }
    }

    static func endDelivery() {
        insideDepth = max(0, insideDepth - 1)
        if insideDepth == 0 && !interactiveArmed {
            loggedBack = false
        }
    }

    /// A pop from a timer or a finished request is not a tap. A pop inside the touch,
    /// and a swipe-back that actually completes, are.
    static func noteBack(force: Bool = false) {
        guard ShakeReportLog.shared.isEnabled else { return }
        guard force || insideDepth > 0 else { return }
        if force {
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastBackTime < 0.3 { return }
        } else if loggedBack {
            return
        }
        lastBackTime = ProcessInfo.processInfo.systemUptime
        loggedBack = true
        recordTap("back")
    }

    static func considerPop(on nav: UINavigationController) {
        ShakeReportPopWatcher.shared.attach(to: nav)
        guard ShakeReportLog.shared.isEnabled else { return }
        if isInteractivePop(nav) {
            armInteractiveBack(on: nav)
            return
        }
        noteBack()
    }

    static func armInteractiveBack(on nav: UINavigationController) {
        guard !interactiveArmed else { return }
        interactiveArmed = true
        guard let coordinator = nav.transitionCoordinator else { return }
        coordinator.notifyWhenInteractionEnds { context in
            interactiveBackFinished(cancelled: context.isCancelled)
        }
    }

    static func interactiveBackFinished(cancelled: Bool) {
        interactiveArmed = false
        if !cancelled {
            noteBack(force: true)
        }
        if insideDepth == 0 {
            loggedBack = false
        }
    }

    static func cancelInteractiveBack() {
        interactiveArmed = false
    }

    /// Swipe-back that never called `popViewController`. A cancelled gesture leaves the stack as it was.
    static func interactivePopEnded(on nav: UINavigationController, countAtBegan: Int?) {
        if interactiveArmed { return }
        if nav.transitionCoordinator != nil {
            armInteractiveBack(on: nav)
            return
        }
        if let before = countAtBegan, nav.viewControllers.count < before {
            noteBack(force: true)
        }
    }

    static func prepare(_ event: UIEvent, in window: UIWindow) -> ShakeReportDelivery {
        observe(event, in: window)
        guard event.type == .touches, !ShakeReportTapCapture.isKeyboardWindow(window) else {
            return ShakeReportDelivery()
        }
        guard let touches = event.allTouches else { return ShakeReportDelivery() }
        var delivery = ShakeReportDelivery()
        for touch in touches {
            let moved = tracks[ObjectIdentifier(touch)]?.moved ?? .greatestFiniteMagnitude
            guard ShakeReportTapCapture.isStationary(moved: moved, tapCount: touch.tapCount),
                  touch.phase == .ended
            else { continue }
            let point = touch.location(in: window)
            let view = touch.view
            // Read the anchor now. The button action inside send() can remove it
            // (the loyalty card's Close) before the tap is recorded.
            let anchorID = DiagnosticTapAnchorView.bestID(at: point, in: window)
            // The glass platter on iOS 27 is often the hit view, and it is not inside UITabBar.
            // The tab button under the finger still carries the item title.
            let direct = view.flatMap { tabSelection(for: $0) }
            let atPoint = tabSelection(at: point, in: window)
            let named = [direct, atPoint].compactMap { $0 }.first { isSpecificTabName($0.name) } ?? direct ?? atPoint
            let onTab = direct != nil || tabButton(at: point, in: window) != nil
            if onTab, let named, isSpecificTabName(named.name) {
                delivery.tabName = named.name
                delivery.switchesTab = delivery.switchesTab || named.switches
            } else if let anchorID {
                delivery.hits.append(ShakeReportHit(view: view ?? window, point: point, anchorID: anchorID))
            } else if let view, !isTabChrome(view), !onTab {
                delivery.hits.append(ShakeReportHit(view: view, point: point, anchorID: nil))
            }
        }
        return delivery
    }

    static func finish(_ delivery: ShakeReportDelivery, event: UIEvent, in window: UIWindow) {
        defer { consumeEndedTouches(in: event) }
        let ended = event.allTouches?.contains { $0.phase == .ended || $0.phase == .cancelled } ?? false
        guard ended, delivery.hasWork, ShakeReportLog.shared.isEnabled else { return }
        if let tab = delivery.tabName, !DiagnosticLines.loggedTapDuringThisDelivery() {
            recordTap(tab)
            // onChange can run after sendEvent returns. It must not write a second tab line.
            DiagnosticTaps.claimTabTapLogged()
        }
        if DiagnosticLines.loggedTapDuringThisDelivery() { return }
        for hit in delivery.hits {
            recordHit(hit.view, at: hit.point, in: window, anchorID: hit.anchorID)
        }
    }

    static func deliver(_ event: UIEvent, in window: UIWindow, send: () -> Void) {
        var delivery = prepare(event, in: window)
        let stationary = isStationaryEnded(event)
        let keyboard = ShakeReportTapCapture.isKeyboardWindow(window)
        var notedTab = false
        if stationary, !keyboard, ShakeReportLog.shared.isEnabled {
            // A named switch is logged here. Any other tap still marks the selection change
            // so a tab the platter hid from hit-testing becomes `tap tab.<id>`, not a route.
            let hookLogsName = delivery.tabName != nil && delivery.switchesTab
            DiagnosticTaps.noteUserTabTap(logsName: hookLogsName)
            notedTab = true
        }
        beginDelivery()
        send()
        if delivery.tabName == nil, stationary, !keyboard,
           let late = tabSelection(forEndedTouchIn: event, window: window),
           isSpecificTabName(late.name),
           !DiagnosticLines.loggedTapDuringThisDelivery() {
            delivery.tabName = late.name
            delivery.switchesTab = delivery.switchesTab || late.switches
            delivery.hits.removeAll { $0.anchorID == nil }
        }
        finish(delivery, event: event, in: window)
        endDelivery()
        if notedTab {
            DiagnosticTaps.endUserTabTurn()
        }
    }

    /// One control, used by the touch hook and by tests that already know the movement.
    static func recordHit(
        _ view: UIView,
        at point: CGPoint,
        in window: UIWindow?,
        anchorID prefetchedAnchor: String? = nil
    ) {
        guard ShakeReportLog.shared.isEnabled else { return }
        // The screen already named this touch (`home.notifications`). Don't add `tap button`.
        guard !DiagnosticLines.loggedTapDuringThisDelivery() else { return }
        if ShakeReportTapCapture.ancestor(UITabBar.self, from: view) != nil { return }
        if loggedBack, ShakeReportTapCapture.ancestor(UINavigationBar.self, from: view) != nil { return }
        let anchorID = prefetchedAnchor ?? window.flatMap { DiagnosticTapAnchorView.bestID(at: point, in: $0) }
        if let anchorID {
            if let safe = ShakeReportTapNaming.safeIdentifier(anchorID) {
                let back = safe == "back" || safe.hasSuffix(".back") || ShakeReportTapNaming.isBackLabel(safe)
                if back {
                    guard !loggedBack else { return }
                    loggedBack = true
                    recordTap("back")
                } else {
                    recordTap(safe)
                }
            }
            return
        }
        let target = ShakeReportTapCapture.target(for: view, window: window)
        guard let name = ShakeReportTapNaming.name(for: target) else { return }
        if name == "back" || target.role == .back {
            guard !loggedBack else { return }
            loggedBack = true
        }
        recordTap(name)
    }

    /// A tap on the tab that is already selected. Selection does not change, so the bar
    /// binding never runs; the touch hook logs it from the item title map.
    static func sameTabRetapName(for view: UIView) -> String? {
        guard let selection = tabSelection(for: view), !selection.switches else { return nil }
        return selection.name
    }

    private static func recordTap(_ name: String) {
        guard loggedNames.insert(name).inserted else { return }
        if name == "back" { loggedBack = true }
        ShakeReportLog.shared.record("tap \(name)")
    }

    private static func isInteractivePop(_ nav: UINavigationController) -> Bool {
        switch nav.interactivePopGestureRecognizer?.state {
        case .began, .changed, .ended:
            return true
        default:
            return false
        }
    }

    private static func observe(_ event: UIEvent, in window: UIWindow) {
        guard let touches = event.allTouches else { return }
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: window)
            switch touch.phase {
            case .began:
                tracks[id] = Track(start: point, moved: 0)
            case .moved, .stationary, .ended:
                guard var track = tracks[id] else { continue }
                let distance = hypot(point.x - track.start.x, point.y - track.start.y)
                track.moved = max(track.moved, distance)
                tracks[id] = track
            case .cancelled:
                tracks[id] = nil
            default:
                break
            }
        }
        if tracks.count > 16 {
            tracks.removeAll()
        }
    }

    private static func consumeEndedTouches(in event: UIEvent) {
        guard let touches = event.allTouches else { return }
        for touch in touches where touch.phase == .ended || touch.phase == .cancelled {
            tracks[ObjectIdentifier(touch)] = nil
        }
    }

    private static func isStationaryEnded(_ event: UIEvent) -> Bool {
        guard let touches = event.allTouches else { return false }
        for touch in touches {
            let moved = tracks[ObjectIdentifier(touch)]?.moved ?? .greatestFiniteMagnitude
            if touch.phase == .ended, ShakeReportTapCapture.isStationary(moved: moved, tapCount: touch.tapCount) {
                return true
            }
        }
        return false
    }

    /// `tab.offers`. A bare `tab` is not enough: the selection callback has the id.
    private static func isSpecificTabName(_ name: String) -> Bool {
        name.hasPrefix("tab.") && name.count > 4
    }

    private static func tabSelection(forEndedTouchIn event: UIEvent, window: UIWindow) -> (name: String, switches: Bool)? {
        guard let touches = event.allTouches else { return nil }
        for touch in touches {
            let moved = tracks[ObjectIdentifier(touch)]?.moved ?? .greatestFiniteMagnitude
            guard touch.phase == .ended,
                  ShakeReportTapCapture.isStationary(moved: moved, tapCount: touch.tapCount)
            else { continue }
            let point = touch.location(in: window)
            if let view = touch.view, let direct = tabSelection(for: view), isSpecificTabName(direct.name) {
                return direct
            }
            if let atPoint = tabSelection(at: point, in: window) {
                return atPoint
            }
        }
        return nil
    }

    /// iOS 27 draws the tab control outside `UITabBar` (a platter plus a selected copy).
    /// The finger's view is often that platter, so the bar is not an ancestor.
    private static func tabSelection(at point: CGPoint, in window: UIWindow) -> (name: String, switches: Bool)? {
        guard let button = tabButton(at: point, in: window) else { return nil }
        if let direct = tabSelection(for: button) { return direct }
        let text = tabText(of: button)
        let target = ShakeReportTapTarget(
            identifier: text.identifier,
            label: text.label,
            role: .tab,
            interactive: true
        )
        let name = ShakeReportTapNaming.name(for: target) ?? "tab"
        return (name, true)
    }

    private static func tabButton(at point: CGPoint, in root: UIView) -> UIView? {
        var found: [UIView] = []
        func walk(_ view: UIView) {
            if view.isHidden || view.alpha < 0.01 { return }
            let name = NSStringFromClass(type(of: view))
            if ShakeReportTapCapture.isTabButtonClass(name) {
                let frame = view.convert(view.bounds, to: root).insetBy(dx: -8, dy: -8)
                if frame.width > 1, frame.height > 1, frame.contains(point) {
                    found.append(view)
                }
            }
            for subview in view.subviews {
                walk(subview)
            }
        }
        walk(root)
        return found.min { lhs, rhs in
            let lhsNamed = lhs.accessibilityLabel?.isEmpty == false
            let rhsNamed = rhs.accessibilityLabel?.isEmpty == false
            if lhsNamed != rhsNamed { return lhsNamed }
            return lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
        }
    }

    private static func tabText(of view: UIView) -> (identifier: String?, label: String?) {
        var identifier: String?
        var label: String?
        func walk(_ node: UIView) {
            if identifier == nil, let id = node.accessibilityIdentifier, !id.isEmpty {
                identifier = id
            }
            if label == nil, let text = node.accessibilityLabel, !text.isEmpty {
                label = text
            }
            for child in node.subviews where identifier == nil || label == nil {
                walk(child)
            }
        }
        walk(view)
        return (identifier, label)
    }

    private static func isTabChrome(_ view: UIView) -> Bool {
        var node: UIView? = view
        while let current = node {
            if current is UITabBar { return true }
            let name = NSStringFromClass(type(of: current))
            if ShakeReportTapCapture.isTabButtonClass(name)
                || name.contains("UITabBar")
                || name.contains("TabButton") {
                return true
            }
            node = current.superview
        }
        return false
    }

    private static func tabSelection(for view: UIView) -> (name: String, switches: Bool)? {
        guard let bar = ShakeReportTapCapture.ancestor(UITabBar.self, from: view) else { return nil }
        let item = tabItem(in: bar, containing: view) ?? tabItemByIndex(in: bar, containing: view)
        let target = ShakeReportTapTarget(
            identifier: item?.accessibilityIdentifier,
            label: item?.title ?? item?.accessibilityLabel,
            role: .tab,
            interactive: true
        )
        let name = ShakeReportTapNaming.name(for: target) ?? "tab"
        let switches = item.map { $0 !== bar.selectedItem } ?? true
        return (name, switches)
    }

    private static func tabItem(in bar: UITabBar, containing view: UIView) -> UITabBarItem? {
        let items = bar.items ?? []
        guard !items.isEmpty else { return nil }
        var node: UIView? = view
        while let current = node {
            if let match = matchingItem(in: items, label: current.accessibilityLabel, identifier: current.accessibilityIdentifier) {
                return match
            }
            if let elements = current.accessibilityElements {
                for element in elements {
                    let object = element as? NSObject
                    let identifier = (element as? UIAccessibilityIdentification)?.accessibilityIdentifier
                    if let match = matchingItem(in: items, label: object?.accessibilityLabel, identifier: identifier) {
                        return match
                    }
                }
            }
            if current === bar { break }
            node = current.superview
        }
        return nil
    }

    /// One button per tab. iOS 27 draws a selected copy and a platter copy at the same x,
    /// so a raw walk sees twice as many `_UITabButton`s as items.
    private static func tabItemByIndex(in bar: UITabBar, containing view: UIView) -> UITabBarItem? {
        let items = bar.items ?? []
        let clusters = tabClusters(in: bar)
        guard items.count == clusters.count, !items.isEmpty else { return nil }
        let point = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: bar)
        guard let index = clusters.enumerated().min(by: { lhs, rhs in
            abs(lhs.element.midX - point.x) < abs(rhs.element.midX - point.x)
        })?.offset else { return nil }
        return items[index]
    }

    private struct TabCluster {
        var midX: CGFloat
        var button: UIView
    }

    private static func tabClusters(in bar: UITabBar) -> [TabCluster] {
        var found: [UIView] = []
        func walk(_ view: UIView) {
            if ShakeReportTapCapture.isTabButtonClass(NSStringFromClass(type(of: view))) {
                found.append(view)
            }
            for subview in view.subviews {
                walk(subview)
            }
        }
        walk(bar)
        var groups: [TabCluster] = []
        for button in found {
            let frame = button.convert(button.bounds, to: bar)
            guard frame.width > 1, frame.height > 1 else { continue }
            if let index = groups.firstIndex(where: { abs($0.midX - frame.midX) < 30 }) {
                let existing = groups[index].button.convert(groups[index].button.bounds, to: bar)
                if frame.width * frame.height >= existing.width * existing.height {
                    groups[index] = TabCluster(midX: frame.midX, button: button)
                }
            } else {
                groups.append(TabCluster(midX: frame.midX, button: button))
            }
        }
        groups.sort { $0.midX < $1.midX }
        if bar.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            groups.reverse()
        }
        return groups
    }

    private static func matchingItem(
        in items: [UITabBarItem],
        label: String?,
        identifier: String?
    ) -> UITabBarItem? {
        if let label, let match = items.first(where: { $0.title == label || $0.accessibilityLabel == label }) {
            return match
        }
        if let identifier, let match = items.first(where: { $0.accessibilityIdentifier == identifier }) {
            return match
        }
        return nil
    }
}
#endif
