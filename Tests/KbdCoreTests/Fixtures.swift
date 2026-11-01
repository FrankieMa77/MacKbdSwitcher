import Foundation
@testable import KbdCore

enum Fixtures {
    static let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    static let repositoryRoot = testsDirectory.deletingLastPathComponent().deletingLastPathComponent()

    static func keyMap(_ name: String) -> KeyMap {
        let url = testsDirectory.appendingPathComponent("Fixtures/keymap-\(name).json")
        return try! KeyMap(json: Data(contentsOf: url))
    }

    static func model(_ language: String) -> LanguageModel {
        let url = repositoryRoot.appendingPathComponent("Resources/ngrams-\(language).tsv")
        return try! LanguageModel(language: language, contentsOf: url)
    }

    static func corpus(_ language: String) -> [String] {
        let url = testsDirectory.appendingPathComponent("Fixtures/corpus-\(language).txt")
        let text = try! String(contentsOf: url, encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).map(String.init)
    }

    static let english = LayoutProfile(id: "com.apple.keylayout.US", keyMap: keyMap("US"), model: model("en"))
    static let russianWin = LayoutProfile(id: "com.apple.keylayout.RussianWin", keyMap: keyMap("RussianWin"), model: model("ru"))
    static let polishPro = LayoutProfile(id: "com.apple.keylayout.PolishPro", keyMap: keyMap("PolishPro"), models: [model("en"), model("pl")])
    static let russian = LayoutProfile(id: "com.apple.keylayout.Russian", keyMap: keyMap("Russian"), model: model("ru"))

    static func strokes(_ text: String, on profile: LayoutProfile) -> [KeyStroke] {
        text.map { profile.keyMap.stroke(for: String($0))! }
    }

    static func typedStrokes(_ text: String, on profile: LayoutProfile) -> [KeyStroke]? {
        var result: [KeyStroke] = []
        for character in text {
            guard let stroke = profile.keyMap.stroke(for: String(character)) else { return nil }
            result.append(stroke)
        }
        return result
    }

    static func clone(of profile: LayoutProfile, id: String) -> LayoutProfile {
        LayoutProfile(id: id, keyMap: profile.keyMap, models: profile.models)
    }

    static func optionOnlyKey(letterIn first: KeyMap, notLetterIn second: KeyMap) -> UInt16? {
        for keyCode in UInt16(0)...50 {
            let stroke = KeyStroke(keyCode: keyCode, option: true)
            let firstIsLetter = first.character(for: stroke).map { $0.count == 1 && $0.first!.isLetter } ?? false
            let secondIsLetter = second.character(for: stroke).map { $0.count == 1 && $0.first!.isLetter } ?? false
            if firstIsLetter && !secondIsLetter && second.character(for: stroke) != nil {
                return keyCode
            }
        }
        return nil
    }

    static func capsLocked(_ strokes: [KeyStroke]) -> [KeyStroke] {
        strokes.map { KeyStroke(keyCode: $0.keyCode, shift: false, capsLock: true) }
    }
}

struct StubLexicon: Lexicon {
    var words: [String: Set<String>]

    func contains(_ word: String, language: String) -> Bool? {
        guard let known = words[language] else { return nil }
        return known.contains(word.lowercased())
    }
}
