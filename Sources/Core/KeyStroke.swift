import Foundation

public struct KeyStroke: Equatable, Hashable, Sendable {
    public let keyCode: UInt16
    public let shift: Bool
    public let capsLock: Bool
    public let option: Bool

    public init(keyCode: UInt16, shift: Bool = false, capsLock: Bool = false, option: Bool = false) {
        self.keyCode = keyCode
        self.shift = shift
        self.capsLock = capsLock
        self.option = option
    }
}
