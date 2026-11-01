import Carbon
import Foundation

enum KeyLayoutTranslator {
    private static let baseModifiers: [UInt32] = [
        0,
        UInt32(shiftKey >> 8) & 0xFF,
        UInt32(alphaLock >> 8) & 0xFF,
        UInt32((shiftKey | alphaLock) >> 8) & 0xFF,
    ]
    private static let optionModifier = UInt32(optionKey >> 8) & 0xFF
    private static let modifierStates: [UInt32] = baseModifiers + baseModifiers.map { $0 | optionModifier }
    private static let highestKeyCode = 50

    static func keyMap(for source: TISInputSource) -> KeyMap? {
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        var table: [UInt16: [String?]] = [:]
        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            for keyCode in 0...highestKeyCode {
                let row = modifierStates.map { character(layout, keyCode: UInt16(keyCode), modifiers: $0) }
                if row.contains(where: { $0 != nil }) {
                    table[UInt16(keyCode)] = row
                }
            }
        }
        return table.isEmpty ? nil : KeyMap(id: InputSources.id(source), table: table)
    }

    private static func character(_ layout: UnsafePointer<UCKeyboardLayout>, keyCode: UInt16, modifiers: UInt32) -> String? {
        var deadKeys: UInt32 = 0
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout,
            keyCode,
            UInt16(kUCKeyActionDown),
            modifiers,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeys,
            buffer.count,
            &length,
            &buffer
        )
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: buffer, count: length)
        guard text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else { return nil }
        return text
    }
}
