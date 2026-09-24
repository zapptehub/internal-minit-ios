/// Typography primitives from the Mode 1 design export.
internal enum DSPrimitiveTypography {
    enum FontFamily: CaseIterable {
        case heading
        case body

        var sourceName: String {
            switch self {
            case .heading: return "Sharp Grotesk SmBold 20"
            case .body: return "SF Pro Display"
            }
        }

        var sourceID: String {
            switch self {
            case .heading: return "VariableID:16:63"
            case .body: return "VariableID:16:64"
            }
        }
    }

    enum FontWeight: CaseIterable {
        case light
        case regular
        case medium
        case semibold
        case bold

        var sourceName: String {
            switch self {
            case .light: return "Light"
            case .regular: return "Regular"
            case .medium: return "Medium"
            case .semibold: return "Semibold"
            case .bold: return "Bold"
            }
        }

        var sourceID: String {
            switch self {
            case .light: return "VariableID:2009:282"
            case .regular: return "VariableID:16:65"
            case .medium: return "VariableID:16:66"
            case .semibold: return "VariableID:16:86"
            case .bold: return "VariableID:16:67"
            }
        }
    }
}
