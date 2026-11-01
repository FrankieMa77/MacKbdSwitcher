import Foundation

public struct DetectorConfiguration: Equatable, Sendable {
    public var margin: Double
    public var floor: Double
    public var lexiconMarginReduction: Double
    public var minimumLetters: Int
    public var punctuationAsLetterBonus: Double

    public init(
        margin: Double,
        floor: Double,
        lexiconMarginReduction: Double,
        minimumLetters: Int,
        punctuationAsLetterBonus: Double = 0
    ) {
        self.margin = margin
        self.floor = floor
        self.lexiconMarginReduction = lexiconMarginReduction
        self.minimumLetters = minimumLetters
        self.punctuationAsLetterBonus = punctuationAsLetterBonus
    }

    public static let standard = DetectorConfiguration(
        margin: 1.0,
        floor: -5.5,
        lexiconMarginReduction: 0.5,
        minimumLetters: 3,
        punctuationAsLetterBonus: 1.0
    )
}

public enum Decision: Equatable, Sendable {
    case keep
    case convert(String)
}

public struct Verdict: Equatable, Sendable {
    public let decision: Decision
    public let currentScore: Double?
    public let alternateScore: Double?
    public let exceptionKey: String?
    public let alternateID: String?

    init(decision: Decision, currentScore: Double?, alternateScore: Double?, exceptionKey: String?, alternateID: String? = nil) {
        self.decision = decision
        self.currentScore = currentScore
        self.alternateScore = alternateScore
        self.exceptionKey = exceptionKey
        self.alternateID = alternateID
    }

    static let keep = Verdict(decision: .keep, currentScore: nil, alternateScore: nil, exceptionKey: nil)
}

public struct ForcedConversion: Equatable, Sendable {
    public let text: String
    public let alternateID: String
}

public struct WordDetector {
    public let configuration: DetectorConfiguration
    private let lexicon: Lexicon?

    private static let addressSuffixes: Set<String> = [
        "com", "org", "net", "ru", "io", "dev", "app", "edu", "gov", "info", "me", "co", "uk", "de",
        "txt", "pdf", "png", "jpg", "md", "swift", "js", "ts", "py", "json",
    ]

    public init(configuration: DetectorConfiguration = .standard, lexicon: Lexicon? = nil) {
        self.configuration = configuration
        self.lexicon = lexicon
    }

    public func evaluate(
        strokes: [KeyStroke],
        current: LayoutProfile,
        alternate: LayoutProfile,
        exceptions: ExceptionStore? = nil
    ) -> Verdict {
        evaluate(strokes: strokes, current: current, alternates: [alternate], exceptions: exceptions)
    }

    public func evaluate(
        strokes: [KeyStroke],
        current: LayoutProfile,
        alternates: [LayoutProfile],
        exceptions: ExceptionStore? = nil
    ) -> Verdict {
        var best: Verdict?
        for alternate in alternates {
            let verdict = evaluatePair(strokes: strokes, current: current, alternate: alternate, exceptions: exceptions)
            guard let held = best else {
                best = verdict
                continue
            }
            let heldConverts = held.decision != .keep
            let converts = verdict.decision != .keep
            if converts != heldConverts {
                if converts { best = verdict }
            } else if (verdict.alternateScore ?? -.infinity) > (held.alternateScore ?? -.infinity) {
                best = verdict
            }
        }
        return best ?? .keep
    }

    private func evaluatePair(
        strokes: [KeyStroke],
        current: LayoutProfile,
        alternate: LayoutProfile,
        exceptions: ExceptionStore?
    ) -> Verdict {
        guard strokes.count >= configuration.minimumLetters,
              let analysis = Analysis(strokes: strokes, current: current, alternate: alternate),
              !analysis.rejectsOptionLetters,
              !analysis.currentCharacters.contains(where: { $0.contains(where: \.isNumber) }),
              !WordDetector.looksLikeAddress(analysis.currentCharacters.joined())
        else {
            return .keep
        }
        var best: Scored?
        for candidate in analysis.candidates() {
            guard let scored = score(candidate, analysis: analysis, current: current, alternate: alternate, strict: true) else {
                continue
            }
            if best == nil || scored.preference > best!.preference {
                best = scored
            }
        }
        guard let best else { return .keep }
        let key = best.currentCore.lowercased()
        let base = Verdict(
            decision: .keep,
            currentScore: best.currentScore,
            alternateScore: best.alternateScore,
            exceptionKey: key,
            alternateID: alternate.id
        )
        if exceptions?.contains(key) == true {
            return base
        }
        if isKnown(best.currentCore, in: current) {
            return base
        }
        var margin = configuration.margin
        if isKnown(best.alternateCore, in: alternate) {
            margin -= configuration.lexiconMarginReduction
        }
        guard best.alternateScore > configuration.floor,
              best.alternateScore - best.currentScore > margin
        else {
            return base
        }
        return Verdict(
            decision: .convert(best.text),
            currentScore: best.currentScore,
            alternateScore: best.alternateScore,
            exceptionKey: key,
            alternateID: alternate.id
        )
    }

    private func isKnown(_ word: String, in profile: LayoutProfile) -> Bool {
        guard let lexicon else { return false }
        return profile.languages.contains { lexicon.contains(word, language: $0) == true }
    }

    public func convert(strokes: [KeyStroke], current: LayoutProfile, alternate: LayoutProfile) -> String? {
        convert(strokes: strokes, current: current, alternates: [alternate])?.text
    }

    public func convert(strokes: [KeyStroke], current: LayoutProfile, alternates: [LayoutProfile]) -> ForcedConversion? {
        guard !strokes.isEmpty else { return nil }
        var best: (conversion: ForcedConversion, preference: Double)?
        for alternate in alternates {
            guard let forced = forcedText(strokes: strokes, current: current, alternate: alternate) else { continue }
            if best == nil || forced.preference > best!.preference {
                best = (ForcedConversion(text: forced.text, alternateID: alternate.id), forced.preference)
            }
        }
        return best?.conversion
    }

    private func forcedText(strokes: [KeyStroke], current: LayoutProfile, alternate: LayoutProfile) -> (text: String, preference: Double)? {
        guard let analysis = Analysis(strokes: strokes, current: current, alternate: alternate) else {
            return alternate.keyMap.text(for: strokes).map { ($0, -.infinity) }
        }
        var best: Scored?
        for candidate in analysis.candidates() {
            guard let scored = score(candidate, analysis: analysis, current: current, alternate: alternate, strict: false) else {
                continue
            }
            if best == nil || scored.preference > best!.preference {
                best = scored
            }
        }
        if let best {
            return (best.text, best.preference)
        }
        return alternate.keyMap.text(for: strokes).map { ($0, -.infinity) }
    }

    private struct Scored {
        let text: String
        let currentCore: String
        let alternateCore: String
        let currentScore: Double
        let alternateScore: Double
        let preference: Double
    }

    private struct Candidate {
        let core: Range<Int>
        let keepLeading: Bool
        let keepTrailing: Bool
    }

    private struct Analysis {
        let currentCharacters: [String]
        let alternateCharacters: [String]
        let currentIsLetter: [Bool]
        let alternateIsLetter: [Bool]
        let leading: Int
        let trailing: Int
        let rejectsOptionLetters: Bool

        init?(strokes: [KeyStroke], current: LayoutProfile, alternate: LayoutProfile) {
            var currentCharacters: [String] = []
            var alternateCharacters: [String] = []
            for stroke in strokes {
                guard let first = current.keyMap.character(for: stroke),
                      let second = alternate.keyMap.character(for: stroke) else {
                    return nil
                }
                currentCharacters.append(first)
                alternateCharacters.append(second)
            }
            func isLetter(_ text: String) -> Bool {
                text.count == 1 && text.first!.isLetter
            }
            let alternateIsLetterValues = alternateCharacters.map(isLetter)
            let currentIsLetterValues = currentCharacters.map(isLetter)
            rejectsOptionLetters = strokes.indices.contains { strokes[$0].option && currentIsLetterValues[$0] && !alternateIsLetterValues[$0] }
            self.currentCharacters = currentCharacters
            self.alternateCharacters = alternateCharacters
            currentIsLetter = currentCharacters.map(isLetter)
            alternateIsLetter = alternateCharacters.map(isLetter)
            guard let firstLetter = currentIsLetter.firstIndex(of: true),
                  let lastLetter = currentIsLetter.lastIndex(of: true) else {
                return nil
            }
            leading = firstLetter
            trailing = strokes.count - 1 - lastLetter
        }

        var count: Int {
            currentCharacters.count
        }

        func candidates() -> [Candidate] {
            var result: [Candidate] = []
            for keepLeading in leading > 0 ? [true, false] : [false] {
                for keepTrailing in trailing > 0 ? [true, false] : [false] {
                    let lower = keepLeading ? leading : 0
                    let upper = keepTrailing ? count - trailing : count
                    result.append(Candidate(core: lower..<upper, keepLeading: keepLeading, keepTrailing: keepTrailing))
                }
            }
            return result
        }

        func asTyped(_ range: Range<Int>) -> String {
            range.map { alternateIsLetter[$0] ? currentCharacters[$0] : alternateCharacters[$0] }.joined()
        }
    }

    private func score(
        _ candidate: Candidate,
        analysis: Analysis,
        current: LayoutProfile,
        alternate: LayoutProfile,
        strict: Bool
    ) -> Scored? {
        let core = candidate.core
        guard !core.isEmpty else { return nil }
        if strict {
            guard core.count >= configuration.minimumLetters, isWordShaped(core, analysis) else { return nil }
        }
        let currentCore = core.map { analysis.currentCharacters[$0] }.joined()
        let alternateCore = core.map { analysis.alternateCharacters[$0] }.joined()
        let prefix = candidate.keepLeading ? analysis.asTyped(0..<analysis.leading) : ""
        let suffix = candidate.keepTrailing ? analysis.asTyped((analysis.count - analysis.trailing)..<analysis.count) : ""
        let promoted = core.filter { !analysis.currentIsLetter[$0] }.count
        let alternateScore = alternate.score(alternateCore)
        return Scored(
            text: prefix + alternateCore + suffix,
            currentCore: currentCore,
            alternateCore: alternateCore,
            currentScore: current.score(currentCore),
            alternateScore: alternateScore,
            preference: alternateScore + configuration.punctuationAsLetterBonus * Double(promoted)
        )
    }

    private func isWordShaped(_ core: Range<Int>, _ analysis: Analysis) -> Bool {
        for index in core {
            let letter = analysis.currentIsLetter[index] || analysis.alternateIsLetter[index]
            let hyphen = analysis.currentCharacters[index] == "-" && analysis.alternateCharacters[index] == "-"
            let inside = index > core.lowerBound && index < core.upperBound - 1
            if !letter && !(hyphen && inside) {
                return false
            }
        }
        let currentLetters = core.filter { analysis.currentIsLetter[$0] }.map { analysis.currentCharacters[$0] }
        let alternateLetters = core.filter { analysis.alternateIsLetter[$0] }.map { analysis.alternateCharacters[$0] }
        return WordDetector.hasPlainCase(currentLetters) && WordDetector.hasPlainCase(alternateLetters)
    }

    private static func hasPlainCase(_ letters: [String]) -> Bool {
        let uppercase = letters.map { $0.first?.isUppercase ?? false }
        guard !uppercase.isEmpty else { return true }
        if uppercase.allSatisfy({ !$0 }) || uppercase.allSatisfy({ $0 }) {
            return true
        }
        return uppercase[0] && uppercase.dropFirst().allSatisfy { !$0 }
    }

    private static func looksLikeAddress(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if lowered.contains("://") || lowered.hasPrefix("www.") {
            return true
        }
        let parts = lowered.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, let last = parts.last, !parts[parts.count - 2].isEmpty else { return false }
        return addressSuffixes.contains(String(last))
    }
}
