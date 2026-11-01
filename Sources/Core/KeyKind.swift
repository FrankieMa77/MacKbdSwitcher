import Foundation

public enum KeyKind: Equatable, Sendable {
    case character
    case boundary(String)
    case backspace
    case reset

    public static let space: UInt16 = 49
    public static let returnKey: UInt16 = 36
    public static let keypadEnter: UInt16 = 76
    public static let tab: UInt16 = 48
    public static let delete: UInt16 = 51

    public static func classify(keyCode: UInt16) -> KeyKind {
        switch keyCode {
        case space:
            return .boundary(" ")
        case returnKey, keypadEnter:
            return .boundary("\n")
        case tab:
            return .boundary("\t")
        case delete:
            return .backspace
        case 0...50:
            return .character
        default:
            return .reset
        }
    }
}
