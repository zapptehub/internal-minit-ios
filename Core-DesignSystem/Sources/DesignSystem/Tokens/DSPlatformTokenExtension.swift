/// Product-owned decisions for domains not present in the Mode 1 design export.
///
/// These declarations keep the source of truth explicit without treating legacy
/// values as primitives. Each domain is migrated only when the export adds it.
internal enum DSPlatformTokenExtension {
    enum BodyTypeface: String {
        case nativeSystem
    }

    enum DesignPendingDomain: String, CaseIterable {
        case typographyMetrics
        case radius
        case border
        case shadow
        case componentMetrics
    }

    static let bodyTypeface: BodyTypeface = .nativeSystem
    static let designPendingDomains = Set(DesignPendingDomain.allCases)
}
