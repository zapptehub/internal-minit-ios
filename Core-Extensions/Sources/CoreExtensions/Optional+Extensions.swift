public extension Optional {
    func or(_ defaultValue: Wrapped) -> Wrapped {
        self ?? defaultValue
    }

    var isNil: Bool { self == nil }

    var isSome: Bool { self != nil }
}
