import CoreFoundation

public enum DSConstant: Int {
    case xSmall = 4
    case smallMedium = 6
    case small = 8
    case medium = 12
    case mediumLarge = 16
    case large = 24
    case xLarge = 32
    case xxLarge = 40

    public var value: CGFloat { CGFloat(rawValue) }
}
