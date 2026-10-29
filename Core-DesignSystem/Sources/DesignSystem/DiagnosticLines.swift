import SwiftUI

/// Optional line recorder. The app installs it for internal builds; a nil recorder drops the line.
public enum DiagnosticLines {
    public nonisolated(unsafe) static var record: (@Sendable (String) -> Void)?

    public static func line(_ text: String) {
        record?(text)
    }
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
}
