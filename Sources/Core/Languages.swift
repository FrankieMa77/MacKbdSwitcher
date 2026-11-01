import Foundation

public enum Alphabet: String, Equatable, Hashable, Sendable {
    case latin
    case cyrillic
}

public struct LanguageInfo: Equatable, Sendable {
    public let code: String
    public let name: String
    public let alphabet: Alphabet

    public init(code: String, name: String, alphabet: Alphabet) {
        self.code = code
        self.name = name
        self.alphabet = alphabet
    }
}

public enum SupportedLanguages {
    public static let all: [LanguageInfo] = [
        LanguageInfo(code: "en", name: "English", alphabet: .latin),
        LanguageInfo(code: "pl", name: "Polski", alphabet: .latin),
        LanguageInfo(code: "ru", name: "Русский", alphabet: .cyrillic),
    ]

    public static func info(for code: String) -> LanguageInfo? {
        all.first { $0.code == code }
    }
}

public enum LayoutLanguages {
    public static func options(for alphabet: Alphabet, available: Set<String>, catalog: [LanguageInfo] = SupportedLanguages.all) -> [String] {
        catalog.filter { $0.alphabet == alphabet && available.contains($0.code) }.map(\.code)
    }

    public static func resolve(
        systemLanguages: [String],
        alphabet: Alphabet,
        available: Set<String>,
        override: [String]?,
        catalog: [LanguageInfo] = SupportedLanguages.all
    ) -> [String] {
        let allowed = options(for: alphabet, available: available, catalog: catalog)
        if let override {
            return allowed.filter { override.contains($0) }
        }
        var chosen: Set<String> = []
        if let primary = systemLanguages.first.map(normalize), allowed.contains(primary) {
            chosen.insert(primary)
        }
        if alphabet == .latin, allowed.contains("en") {
            chosen.insert("en")
        }
        return allowed.filter { chosen.contains($0) }
    }

    public static func toggled(_ language: String, in current: [String], allowed: [String]) -> [String] {
        var selected = Set(current)
        if selected.contains(language) {
            selected.remove(language)
        } else if allowed.contains(language) {
            selected.insert(language)
        }
        return allowed.filter { selected.contains($0) }
    }

    public static func normalize(_ language: String) -> String {
        String(language.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "").lowercased()
    }
}
