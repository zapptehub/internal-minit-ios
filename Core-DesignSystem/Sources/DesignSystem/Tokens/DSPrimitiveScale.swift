import CoreGraphics

/// Numeric scale primitives from the Mode 1 design export.
internal struct DSPrimitiveScaleToken: Equatable, Sendable {
    let value: CGFloat
    let sourceID: String
}

internal enum DSPrimitiveScale {
    static let step0 = DSPrimitiveScaleToken(value: 0, sourceID: "VariableID:16:71")
    static let step50 = DSPrimitiveScaleToken(value: 2, sourceID: "VariableID:16:79")
    static let step100 = DSPrimitiveScaleToken(value: 4, sourceID: "VariableID:16:68")
    static let step200 = DSPrimitiveScaleToken(value: 8, sourceID: "VariableID:16:69")
    static let step300 = DSPrimitiveScaleToken(value: 12, sourceID: "VariableID:16:70")
    static let step400 = DSPrimitiveScaleToken(value: 16, sourceID: "VariableID:16:72")
    static let step500 = DSPrimitiveScaleToken(value: 20, sourceID: "VariableID:16:73")
    static let step600 = DSPrimitiveScaleToken(value: 24, sourceID: "VariableID:16:74")
    static let step700 = DSPrimitiveScaleToken(value: 28, sourceID: "VariableID:16:75")
    static let step800 = DSPrimitiveScaleToken(value: 32, sourceID: "VariableID:16:76")
    static let step900 = DSPrimitiveScaleToken(value: 36, sourceID: "VariableID:16:77")
    static let step1000 = DSPrimitiveScaleToken(value: 40, sourceID: "VariableID:16:78")
    static let step1100 = DSPrimitiveScaleToken(value: 44, sourceID: "VariableID:16:80")
    static let step1200 = DSPrimitiveScaleToken(value: 48, sourceID: "VariableID:16:81")
    static let step1300 = DSPrimitiveScaleToken(value: 52, sourceID: "VariableID:16:82")
    static let step1400 = DSPrimitiveScaleToken(value: 56, sourceID: "VariableID:16:83")
    static let step1500 = DSPrimitiveScaleToken(value: 60, sourceID: "VariableID:16:84")
    static let step1600 = DSPrimitiveScaleToken(value: 64, sourceID: "VariableID:16:85")

    static let all: [String: DSPrimitiveScaleToken] = [
        "scale.0": step0,
        "scale.50": step50,
        "scale.100": step100,
        "scale.200": step200,
        "scale.300": step300,
        "scale.400": step400,
        "scale.500": step500,
        "scale.600": step600,
        "scale.700": step700,
        "scale.800": step800,
        "scale.900": step900,
        "scale.1000": step1000,
        "scale.1100": step1100,
        "scale.1200": step1200,
        "scale.1300": step1300,
        "scale.1400": step1400,
        "scale.1500": step1500,
        "scale.1600": step1600,
    ]
}
