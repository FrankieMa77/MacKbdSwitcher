import Foundation

public struct KeyMap: Equatable, Sendable {
    public let id: String
    private let table: [UInt16: [String?]]

    public init(id: String, table: [UInt16: [String?]]) {
        self.id = id
        self.table = table
    }

    public init(json: Data) throws {
        struct Document: Decodable {
            let id: String
            let keys: [String: [String?]]
        }
        let document = try JSONDecoder().decode(Document.self, from: json)
        var table: [UInt16: [String?]] = [:]
        for (key, row) in document.keys {
            guard let keyCode = UInt16(key) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad key code \(key)"))
            }
            table[keyCode] = row
        }
        self.init(id: document.id, table: table)
    }

    public func character(for stroke: KeyStroke) -> String? {
        guard let row = table[stroke.keyCode] else { return nil }
        let index = (stroke.shift ? 1 : 0) + (stroke.capsLock ? 2 : 0) + (stroke.option ? 4 : 0)
        guard index < row.count else { return nil }
        return row[index]
    }

    public func isLetter(keyCode: UInt16) -> Bool {
        guard let character = character(for: KeyStroke(keyCode: keyCode)) else { return false }
        return character.count == 1 && character.first!.isLetter
    }

    public func text(for strokes: [KeyStroke]) -> String? {
        var result = ""
        for stroke in strokes {
            guard let character = character(for: stroke) else { return nil }
            result += character
        }
        return result
    }

    public func stroke(for character: String) -> KeyStroke? {
        let candidates = table.keys.sorted()
        for option in [false, true] {
            for shift in [false, true] {
                for keyCode in candidates {
                    let stroke = KeyStroke(keyCode: keyCode, shift: shift, option: option)
                    if self.character(for: stroke) == character {
                        return stroke
                    }
                }
            }
        }
        return nil
    }

    public var alphabet: Alphabet? {
        var latin = 0
        var cyrillic = 0
        for keyCode in table.keys {
            guard let character = character(for: KeyStroke(keyCode: keyCode)), character.count == 1,
                  let scalar = character.unicodeScalars.first, character.first!.isLetter else { continue }
            if scalar.isASCII || (0x00C0...0x024F).contains(scalar.value) {
                latin += 1
            } else if (0x0400...0x04FF).contains(scalar.value) {
                cyrillic += 1
            }
        }
        let threshold = 10
        if latin >= threshold && latin > cyrillic {
            return .latin
        }
        if cyrillic >= threshold && cyrillic > latin {
            return .cyrillic
        }
        return nil
    }
}
