import Carbon
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let outputDirectory = arguments.first ?? "Tests/KbdCoreTests/Fixtures"
let layoutIDs = arguments.count > 1
    ? Array(arguments.dropFirst())
    : ["com.apple.keylayout.US", "com.apple.keylayout.Russian", "com.apple.keylayout.RussianWin", "com.apple.keylayout.PolishPro"]

let baseModifiers: [UInt32] = [0, UInt32(shiftKey >> 8) & 0xFF, UInt32(alphaLock >> 8) & 0xFF, UInt32((shiftKey | alphaLock) >> 8) & 0xFF]
let optionModifier = UInt32(optionKey >> 8) & 0xFF
let modifierStates: [UInt32] = baseModifiers + baseModifiers.map { $0 | optionModifier }

func source(_ id: String) -> TISInputSource? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else {
        return nil
    }
    return list.first
}

func character(_ layout: UnsafePointer<UCKeyboardLayout>, keyCode: UInt16, modifiers: UInt32) -> String? {
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

func dump(_ id: String) -> Bool {
    guard let source = source(id),
          let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
        FileHandle.standardError.write(Data("no key layout data for \(id)\n".utf8))
        return false
    }
    let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
    var keys: [String: [String?]] = [:]
    data.withUnsafeBytes { bytes in
        let layout = bytes.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self)
        for keyCode in 0...50 {
            let row = modifierStates.map { character(layout, keyCode: UInt16(keyCode), modifiers: $0) }
            if row.contains(where: { $0 != nil }) {
                keys[String(keyCode)] = row
            }
        }
    }
    let document: [String: Any] = ["id": id, "keys": keys.mapValues { row in row.map { $0 as Any? ?? NSNull() } }]
    guard let json = try? JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys]) else {
        return false
    }
    let name = id.split(separator: ".").last.map(String.init) ?? id
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent("keymap-\(name).json")
    do {
        try json.write(to: url)
    } catch {
        FileHandle.standardError.write(Data("cannot write \(url.path)\n".utf8))
        return false
    }
    print("wrote \(url.path)")
    return true
}

let succeeded = layoutIDs.map(dump)
exit(succeeded.allSatisfy { $0 } ? 0 : 1)
