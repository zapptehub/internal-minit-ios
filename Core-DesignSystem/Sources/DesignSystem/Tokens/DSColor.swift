import SwiftUI

public enum DSColor {
    public enum Text {
        public static let primary = Color("Text/Primary", bundle: .module)
        public static let secondary = Color("Text/Secondary", bundle: .module)
        /// Brand-tinted heading color (#331A00) — a distinct, hardcoded value in Figma,
        /// not the generic "text/headings" token. Used for large display headlines only.
        public static let heading = Color("Text/Heading", bundle: .module)
        public static let tertiary = Color("Text/Tertiary", bundle: .module)
        public static let active = Color("Text/Active", bundle: .module)
        public static let disabled = Color("Text/Disabled", bundle: .module)
        /// White text for use on dark/photo backgrounds (Figma's "text/headings-invert",
        /// "text/body-invert"). Named `inverse`, not `onPrimary` — it has no relation to
        /// `Text.primary` or any "primary" surface; it's simply the inverse of normal text.
        public static let inverse = Color("Text/Inverse", bundle: .module)
        public static let onColorButton = Color("Text/OnColorButton", bundle: .module)
        /// Error-state label/value text (form fields). Same hue as `Border.error`.
        public static let error = Color("Text/Error", bundle: .module)
        /// Success-state label/value text (form fields). Same hue as `Border.success`.
        public static let success = Color("Text/Success", bundle: .module)
        /// Brand-orange highlight for a single emphasized word/phrase inside otherwise
        /// normal-colored text (e.g. the name in "Welcome back <Name>", or the email
        /// address in the verification-code subtitle). Same hex as
        /// `Background.Button.primary` (`#FF9A31`) — no dedicated Figma token to copy
        /// this round, see `plans/ios-auth-flow-multi-step.md`.
        public static let accent = Color("Text/Accent", bundle: .module)
        /// Interactive link text (e.g. "Contact Support if you lost access to 2FA") — `#2C80ED`.
        public static let link = Color("Text/Link", bundle: .module)
    }

    public enum Background {
        public enum Layer {
            public static let level0 = Color("Background/Layer/Level0", bundle: .module)
            public static let level1 = Color("Background/Layer/Level1", bundle: .module)
        }
        public enum Button {
            public static let primary = Color("Background/Button/Primary", bundle: .module)
            public static let secondary = Color("Background/Button/Secondary", bundle: .module)
            public static let tertiary = Color("Background/Button/Tertiary", bundle: .module)
            public static let disabled = Color("Background/Button/Disabled", bundle: .module)
            /// Hot-orange accent (`#FF8200`) — distinct from `primary` (`#FF9A31`). Used for
            /// `DSSelectableRowGroup`'s selected-row fill.
            public static let accent = Color("Background/Button/Accent", bundle: .module)
        }
        /// `#331A00` — same hex as `Text.heading`, coincidentally; this is a distinct token
        /// so banner fills don't semantically depend on a text color. Home's first promo
        /// banner slot until real banner artwork/copy exists.
        public static let brown = Color("Background/Brown", bundle: .module)
        /// `#C91157` — same brand pink as `LoyaltyCard`'s rank-progress ring /
        /// `minitArmorIcon`. Home's second promo banner slot.
        public static let pink = Color("Background/Pink", bundle: .module)
        /// `#094528`. Home's third promo banner slot.
        public static let green = Color("Background/Green", bundle: .module)
        /// `#FF9A31` — same hex as `Text.accent`/`Background.Button.primary`, coincidentally;
        /// distinct token so card fills don't semantically depend on a button/text color.
        /// First challenge-card slot.
        public static let orange = Color("Background/Orange", bundle: .module)
        public enum Control {
            /// Checked `DSCheckbox` / selected `DSRadio` fill. Unchecked/unselected controls
            /// stay unfilled (stroke-only against the surrounding layer background), so there
            /// is no corresponding `.default` fill token.
            public static let selected = Color("Background/Control/Selected", bundle: .module)
        }
        public enum Icon {
            /// Filled circle behind a success glyph (e.g. `PasswordChangedScreen`'s checkmark).
            /// Distinct, hardcoded sage-green — no dedicated Figma token to copy this round,
            /// see `plans/ios-auth-flow-multi-step.md`.
            public static let success = Color("Background/Icon/Success", bundle: .module)
            /// Filled circle behind `DSProgressView`'s spinner glyph (`#EDEDED`). Distinct,
            /// hardcoded neutral gray — no dedicated Figma token to copy this round, same
            /// rationale as `success` above.
            public static let loading = Color("Background/Icon/Loading", bundle: .module)
        }
    }

    public enum Icon {
        public static let primary = Color("Icon/Primary", bundle: .module)
        public static let secondary = Color("Icon/Secondary", bundle: .module)
        public static let active = Color("Icon/Active", bundle: .module)
        public static let disabled = Color("Icon/Disabled", bundle: .module)
    }

    public enum Border {
        public static let `default` = Color("Border/Default", bundle: .module)
        public static let active = Color("Border/Active", bundle: .module)
        public static let error = Color("Border/Error", bundle: .module)
        public static let success = Color("Border/Success", bundle: .module)
        public static let disabled = Color("Border/Disabled", bundle: .module)
    }
}
