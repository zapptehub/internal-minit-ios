/// Product color roles expressed as aliases to primitive or platform-extension tokens.
internal enum DSSemanticColor {
    enum Brand {
        static let secondary = DSPrimitiveColor.DeepClaret.tone500
        static let secondarySubtle = DSPrimitiveColor.DeepClaret.tone100
    }

    enum Text {
        static let primary = DSPrimitiveColor.Grey.tone900
        static let secondary = DSPrimitiveColor.Grey.tone600
        static let heading = DSPrimitiveColor.Brown.tone500
        static let tertiary = DSPrimitiveColor.Grey.tone300
        static let active = primary
        static let disabled = tertiary
        static let inverse = DSPrimitiveColor.white
        static let onColorButton = inverse
        static let error = DSPrimitiveColor.Red.tone700
        static let success = DSPrimitiveColor.Green.tone700
        static let accent = DSPrimitiveColor.Minit.tone400
        static let link = DSPrimitiveColor.Blue.tone500
    }

    enum Background {
        enum Layer {
            static let level0 = DSPrimitiveColor.white
            static let level1 = DSPrimitiveColor.Grey.tone50
        }

        enum Button {
            static let primary = Text.accent
            static let secondary = Brand.secondary
            static let tertiary = DSPrimitiveColor.black
            static let disabled = Layer.level1
            static let accent = DSPrimitiveColor.Minit.tone500
        }

        static let brown = Text.heading
        static let pink = Brand.secondary
        static let green = DSPrimitiveColor.DeepGreen.tone500
        static let orange = Text.accent

        enum Control {
            static let selected = DSPlatformColorExtension.controlSelected
        }

        enum Icon {
            static let success = DSPrimitiveColor.Green.tone600
            static let loading = DSPlatformColorExtension.iconBackgroundLoading
        }
    }

    enum Icon {
        static let primary = Text.primary
        static let secondary = Text.secondary
        static let active = Text.active
        static let disabled = Text.disabled
    }

    enum Border {
        static let `default` = DSPrimitiveColor.Grey.tone100
        static let active = DSPrimitiveColor.Grey.tone400
        static let error = DSPrimitiveColor.Red.tone500
        static let success = DSPrimitiveColor.Green.tone500
        static let disabled = `default`
    }
}
