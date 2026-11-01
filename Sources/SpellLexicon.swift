import AppKit

final class SpellLexicon: Lexicon {
    private var resolved: [String: String?] = [:]

    func contains(_ word: String, language: String) -> Bool? {
        guard let spellLanguage = spellLanguage(for: language) else { return nil }
        let checker = NSSpellChecker.shared
        let lowered = word.lowercased()
        let capitalized = lowered.prefix(1).uppercased() + lowered.dropFirst()
        for candidate in [lowered, capitalized] {
            let range = checker.checkSpelling(
                of: candidate,
                startingAt: 0,
                language: spellLanguage,
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: nil
            )
            if range.location == NSNotFound {
                return true
            }
        }
        return false
    }

    private func spellLanguage(for language: String) -> String? {
        if let cached = resolved[language] {
            return cached
        }
        let available = NSSpellChecker.shared.availableLanguages
        let match = available.first { $0 == language }
            ?? available.first { $0.hasPrefix(language + "_") || $0.hasPrefix(language + "-") }
        resolved[language] = match
        return match
    }
}
