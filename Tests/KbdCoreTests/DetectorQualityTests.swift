import Foundation
import Testing
@testable import KbdCore

struct QualityResult {
    let typable: Int
    let converted: Int
    let falseConversions: Int
    let misses: [String]
    let falsePositives: [String]

    var conversionRate: Double {
        Double(converted) / Double(typable)
    }

    var falsePositiveRate: Double {
        Double(falseConversions) / Double(typable)
    }
}

func measureQuality(
    words: [String],
    language: LayoutProfile,
    other: LayoutProfile,
    detector: WordDetector = WordDetector(),
    transform: (String) -> String = { $0 }
) -> QualityResult {
    var typable = 0
    var converted = 0
    var falseConversions = 0
    var misses: [String] = []
    var falsePositives: [String] = []
    for original in words {
        let word = transform(original)
        guard let strokes = Fixtures.typedStrokes(word, on: language) else { continue }
        typable += 1
        let wrongLayout = detector.evaluate(strokes: strokes, current: other, alternate: language)
        if wrongLayout.decision == .convert(word) {
            converted += 1
        } else {
            misses.append(word)
        }
        let rightLayout = detector.evaluate(strokes: strokes, current: language, alternate: other)
        if rightLayout.decision != .keep {
            falseConversions += 1
            falsePositives.append(word)
        }
    }
    return QualityResult(typable: typable, converted: converted, falseConversions: falseConversions, misses: misses, falsePositives: falsePositives)
}

func measureCrossLayout(
    words: [String],
    intended: LayoutProfile,
    wrong: LayoutProfile,
    detector: WordDetector = WordDetector()
) -> (convertible: QualityResult, allTypable: Int, falsePositiveRate: Double, falsePositives: [String]) {
    var typableOnBoth = 0
    var converted = 0
    var misses: [String] = []
    var typable = 0
    var falsePositives: [String] = []
    for word in words {
        guard let strokes = Fixtures.typedStrokes(word, on: intended) else { continue }
        typable += 1
        if detector.evaluate(strokes: strokes, current: intended, alternate: wrong).decision != .keep {
            falsePositives.append(word)
        }
        guard strokes.allSatisfy({ !$0.option }) else { continue }
        typableOnBoth += 1
        if detector.evaluate(strokes: strokes, current: wrong, alternate: intended).decision == .convert(word) {
            converted += 1
        } else {
            misses.append(word)
        }
    }
    let result = QualityResult(typable: typableOnBoth, converted: converted, falseConversions: 0, misses: misses, falsePositives: [])
    return (result, typable, Double(falsePositives.count) / Double(typable), falsePositives)
}

@Suite struct PolishPairQualityTests {
    static let conversionFloor = 0.975
    static let falsePositiveCeiling = 0.003

    @Test func polishCorpusHoldsTwoThousandWords() {
        let words = Fixtures.corpus("pl")
        #expect(words.count == 2000)
        #expect(words.allSatisfy { $0.count >= 3 })
    }

    @Test func polishCorpusIsFullyTypableOnPolishPro() {
        let typable = Fixtures.corpus("pl").filter { Fixtures.typedStrokes($0, on: Fixtures.polishPro) != nil }
        #expect(typable.count == 2000)
    }

    @Test func englishWordsTypedOnRussianLayoutBecomeEnglishOnPolishPro() {
        let result = measureCrossLayout(words: Fixtures.corpus("en"), intended: Fixtures.polishPro, wrong: Fixtures.russianWin)
        #expect(result.convertible.typable >= 1990)
        #expect(result.convertible.conversionRate >= Self.conversionFloor, "misses: \(result.convertible.misses.prefix(30))")
    }

    @Test func polishWordsWithoutDiacriticsTypedOnRussianLayoutBecomePolish() {
        let result = measureCrossLayout(words: Fixtures.corpus("pl"), intended: Fixtures.polishPro, wrong: Fixtures.russianWin)
        #expect(result.convertible.typable >= 1000)
        #expect(result.convertible.conversionRate >= Self.conversionFloor, "misses: \(result.convertible.misses.prefix(30))")
    }

    @Test func russianWordsTypedOnPolishProBecomeRussian() {
        let result = measureCrossLayout(words: Fixtures.corpus("ru"), intended: Fixtures.russianWin, wrong: Fixtures.polishPro)
        #expect(result.convertible.typable >= 1990)
        #expect(result.convertible.conversionRate >= Self.conversionFloor, "misses: \(result.convertible.misses.prefix(30))")
    }

    @Test func englishWordsTypedCorrectlyOnPolishProAreLeftAlone() {
        let result = measureCrossLayout(words: Fixtures.corpus("en"), intended: Fixtures.polishPro, wrong: Fixtures.russianWin)
        #expect(result.falsePositiveRate <= Self.falsePositiveCeiling, "false positives: \(result.falsePositives.prefix(30))")
    }

    @Test func polishWordsTypedCorrectlyOnPolishProAreLeftAloneIncludingDiacritics() {
        let result = measureCrossLayout(words: Fixtures.corpus("pl"), intended: Fixtures.polishPro, wrong: Fixtures.russianWin)
        #expect(result.allTypable == 2000)
        #expect(result.falsePositiveRate <= Self.falsePositiveCeiling, "false positives: \(result.falsePositives.prefix(30))")
    }

    @Test func russianWordsTypedCorrectlyAreLeftAloneWithPolishAlternate() {
        let result = measureCrossLayout(words: Fixtures.corpus("ru"), intended: Fixtures.russianWin, wrong: Fixtures.polishPro)
        #expect(result.falsePositiveRate <= Self.falsePositiveCeiling, "false positives: \(result.falsePositives.prefix(30))")
    }

    @Test func polishWordsWithDiacriticsAreNotTypableOnRussianLayout() {
        let withDiacritics = Fixtures.corpus("pl").filter { Fixtures.typedStrokes($0, on: Fixtures.polishPro)!.contains(where: \.option) }
        #expect(withDiacritics.count > 500)
        for word in withDiacritics.prefix(50) {
            let strokes = Fixtures.typedStrokes(word, on: Fixtures.polishPro)!
            #expect(WordDetector().evaluate(strokes: strokes, current: Fixtures.polishPro, alternate: Fixtures.russianWin).decision == .keep, "\(word)")
        }
    }

    @Test func threeLayoutSetupMeetsTheSameQualityWithBothLatinAlternates() {
        let detector = WordDetector()
        var converted = 0
        var total = 0
        for word in Fixtures.corpus("en") {
            guard let strokes = Fixtures.typedStrokes(word, on: Fixtures.english) else { continue }
            total += 1
            let verdict = detector.evaluate(
                strokes: strokes,
                current: Fixtures.russianWin,
                alternates: [Fixtures.polishPro, Fixtures.english]
            )
            if verdict.decision == .convert(word) {
                converted += 1
            }
        }
        #expect(Double(converted) / Double(total) >= Self.conversionFloor)
    }
}

@Suite struct DetectorQualityTests {
    static let conversionFloor = 0.975
    static let falsePositiveCeiling = 0.003

    @Test func corpusFilesHoldTwoThousandWordsOfAtLeastThreeLetters() {
        for language in ["en", "ru"] {
            let words = Fixtures.corpus(language)
            #expect(words.count == 2000)
            #expect(words.allSatisfy { $0.count >= 3 })
        }
    }

    @Test func englishWordsTypedOnRussianLayoutAreConverted() {
        let result = measureQuality(words: Fixtures.corpus("en"), language: Fixtures.english, other: Fixtures.russianWin)
        #expect(result.typable >= 1990)
        #expect(result.conversionRate >= Self.conversionFloor, "misses: \(result.misses.prefix(30))")
    }

    @Test func englishWordsTypedCorrectlyAreLeftAlone() {
        let result = measureQuality(words: Fixtures.corpus("en"), language: Fixtures.english, other: Fixtures.russianWin)
        #expect(result.falsePositiveRate <= Self.falsePositiveCeiling, "false positives: \(result.falsePositives.prefix(30))")
    }

    @Test func russianWordsTypedOnEnglishLayoutAreConverted() {
        let result = measureQuality(words: Fixtures.corpus("ru"), language: Fixtures.russianWin, other: Fixtures.english)
        #expect(result.typable >= 1990)
        #expect(result.conversionRate >= Self.conversionFloor, "misses: \(result.misses.prefix(30))")
    }

    @Test func russianWordsTypedCorrectlyAreLeftAlone() {
        let result = measureQuality(words: Fixtures.corpus("ru"), language: Fixtures.russianWin, other: Fixtures.english)
        #expect(result.falsePositiveRate <= Self.falsePositiveCeiling, "false positives: \(result.falsePositives.prefix(30))")
    }

    @Test func appleRussianLayoutMeetsTheSameQuality() {
        let russian = measureQuality(words: Fixtures.corpus("ru"), language: Fixtures.russian, other: Fixtures.english)
        let english = measureQuality(words: Fixtures.corpus("en"), language: Fixtures.english, other: Fixtures.russian)
        #expect(russian.conversionRate >= Self.conversionFloor, "misses: \(russian.misses.prefix(30))")
        #expect(english.conversionRate >= Self.conversionFloor, "misses: \(english.misses.prefix(30))")
        #expect(russian.falsePositiveRate <= Self.falsePositiveCeiling)
        #expect(english.falsePositiveRate <= Self.falsePositiveCeiling)
    }

    @Test func capitalizedWordsMeetTheSameQuality() {
        let capitalize: (String) -> String = { $0.prefix(1).uppercased() + $0.dropFirst() }
        let russian = measureQuality(words: Fixtures.corpus("ru"), language: Fixtures.russianWin, other: Fixtures.english, transform: capitalize)
        let english = measureQuality(words: Fixtures.corpus("en"), language: Fixtures.english, other: Fixtures.russianWin, transform: capitalize)
        #expect(russian.conversionRate >= Self.conversionFloor, "misses: \(russian.misses.prefix(30))")
        #expect(english.conversionRate >= Self.conversionFloor, "misses: \(english.misses.prefix(30))")
        #expect(russian.falsePositiveRate <= Self.falsePositiveCeiling)
        #expect(english.falsePositiveRate <= Self.falsePositiveCeiling)
    }

    @Test func uppercaseWordsMeetTheSameQuality() {
        let shout: (String) -> String = { $0.uppercased() }
        let russian = measureQuality(words: Fixtures.corpus("ru"), language: Fixtures.russianWin, other: Fixtures.english, transform: shout)
        let english = measureQuality(words: Fixtures.corpus("en"), language: Fixtures.english, other: Fixtures.russianWin, transform: shout)
        #expect(russian.conversionRate >= Self.conversionFloor, "misses: \(russian.misses.prefix(30))")
        #expect(english.conversionRate >= Self.conversionFloor, "misses: \(english.misses.prefix(30))")
        #expect(russian.falsePositiveRate <= Self.falsePositiveCeiling)
        #expect(english.falsePositiveRate <= Self.falsePositiveCeiling)
    }
}
