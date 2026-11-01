import CoreGraphics
import Foundation

enum EventPoster {
    static let marker: Int64 = 0x4D4B4247
    private static let backspaceKeyCode: CGKeyCode = 51
    private static let returnKeyCode: CGKeyCode = 36
    private static let tabKeyCode: CGKeyCode = 48
    private static let chunkLimit = 20
    private static let source = CGEventSource(stateID: .hidSystemState)

    static func replace(deleteCount: Int, text: String) {
        for _ in 0..<deleteCount {
            press(keyCode: backspaceKeyCode)
        }
        var pending = ""
        func flush() {
            for chunk in TextChunks.split(pending, limit: chunkLimit) {
                type(chunk)
            }
            pending = ""
        }
        for character in text {
            switch character {
            case "\n":
                flush()
                press(keyCode: returnKeyCode)
            case "\t":
                flush()
                press(keyCode: tabKeyCode)
            default:
                pending.append(character)
            }
        }
        flush()
    }

    private static func press(keyCode: CGKeyCode) {
        post(keyCode: keyCode, text: nil)
    }

    private static func type(_ text: String) {
        post(keyCode: 0, text: text)
    }

    private static func post(keyCode: CGKeyCode, text: String?) {
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else { continue }
            event.flags = []
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            if let text {
                let units = Array(text.utf16)
                event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            }
            event.post(tap: .cgSessionEventTap)
        }
    }
}
