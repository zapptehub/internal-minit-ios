import SwiftUI

/// Shared accessibility copy from `common.a11y.*`, resolved with the caller's locale.
enum DesignSystemA11y {
    static func text(_ key: String, locale: Locale) -> String {
        DesignSystemLocalizedString.string(key, locale: locale)
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        String(
            format: DesignSystemLocalizedString.string(key, locale: locale),
            locale: locale,
            arguments: arguments
        )
    }
}

extension View {
    @ViewBuilder
    func dsAccessibilityHint(_ hint: String?) -> some View {
        if let hint, !hint.isEmpty {
            accessibilityHint(hint)
        } else {
            self
        }
    }

    @ViewBuilder
    func dsAccessibilityValue(_ value: String?) -> some View {
        if let value, !value.isEmpty {
            accessibilityValue(value)
        } else {
            self
        }
    }
}
