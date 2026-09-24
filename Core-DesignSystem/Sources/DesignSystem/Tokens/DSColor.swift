import SwiftUI

public enum DSColor {
    public enum Text {
        public static let primary = DSSemanticColor.Text.primary.color
        public static let secondary = DSSemanticColor.Text.secondary.color
        public static let heading = DSSemanticColor.Text.heading.color
        public static let tertiary = DSSemanticColor.Text.tertiary.color
        public static let active = DSSemanticColor.Text.active.color
        public static let disabled = DSSemanticColor.Text.disabled.color
        public static let inverse = DSSemanticColor.Text.inverse.color
        public static let onColorButton = DSSemanticColor.Text.onColorButton.color
        public static let error = DSSemanticColor.Text.error.color
        public static let success = DSSemanticColor.Text.success.color
        public static let accent = DSSemanticColor.Text.accent.color
        public static let link = DSSemanticColor.Text.link.color
    }

    public enum Background {
        public enum Layer {
            public static let level0 = DSSemanticColor.Background.Layer.level0.color
            public static let level1 = DSSemanticColor.Background.Layer.level1.color
        }
        public enum Button {
            public static let primary = DSSemanticColor.Background.Button.primary.color
            public static let secondary = DSSemanticColor.Background.Button.secondary.color
            public static let tertiary = DSSemanticColor.Background.Button.tertiary.color
            public static let disabled = DSSemanticColor.Background.Button.disabled.color
            public static let accent = DSSemanticColor.Background.Button.accent.color
        }
        public static let brown = DSSemanticColor.Background.brown.color
        public static let pink = DSSemanticColor.Background.pink.color
        public static let green = DSSemanticColor.Background.green.color
        public static let orange = DSSemanticColor.Background.orange.color
        public enum Control {
            public static let selected = DSSemanticColor.Background.Control.selected.color
        }
        public enum Icon {
            public static let success = DSSemanticColor.Background.Icon.success.color
            public static let loading = DSSemanticColor.Background.Icon.loading.color
        }
    }

    public enum Icon {
        public static let primary = DSSemanticColor.Icon.primary.color
        public static let secondary = DSSemanticColor.Icon.secondary.color
        public static let active = DSSemanticColor.Icon.active.color
        public static let disabled = DSSemanticColor.Icon.disabled.color
    }

    public enum Border {
        public static let `default` = DSSemanticColor.Border.default.color
        public static let active = DSSemanticColor.Border.active.color
        public static let error = DSSemanticColor.Border.error.color
        public static let success = DSSemanticColor.Border.success.color
        public static let disabled = DSSemanticColor.Border.disabled.color
    }
}
