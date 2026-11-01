import Foundation
import Testing
@testable import KbdCore

@Suite struct WordDetectorTests {
    let detector = WordDetector()
    let english = Fixtures.english
    let russian = Fixtures.russianWin

    func typedOnEnglish(_ keys: String) -> Verdict {
        detector.evaluate(strokes: Fixtures.strokes(keys, on: english), current: english, alternate: russian)
    }

    func typedOnRussian(_ keys: String) -> Verdict {
        detector.evaluate(strokes: Fixtures.strokes(keys, on: russian), current: russian, alternate: english)
    }

    @Test(arguments: [
        ("ghbdtn", "привет"),
        ("Ghbdtn", "Привет"),
        ("GHBDTN", "ПРИВЕТ"),
        ("j,sxysq", "обычный"),
        ("ghbdtn,", "привет,"),
        ("[kt,", "хлеб"),
        ("k.,jdm", "любовь"),
        ("cgfcb,j", "спасибо"),
    ])
    func englishKeysBecomeRussianWords(keys: String, expected: String) {
        let verdict = typedOnEnglish(keys)
        #expect(verdict.decision == .convert(expected))
    }

    @Test(arguments: [
        ("руддщ", "hello"),
        ("цщкдв", "world"),
        ("вщтэе", "don't"),
    ])
    func russianKeysBecomeEnglishWords(keys: String, expected: String) {
        let verdict = typedOnRussian(keys)
        #expect(verdict.decision == .convert(expected))
    }

    @Test(arguments: ["ok", "iPhone", "abc123", "hello", "world", "github.com", "www.example", "http://x", "k", "McDonald"])
    func englishInputIsKept(keys: String) {
        #expect(typedOnEnglish(keys).decision == .keep)
    }

    @Test(arguments: ["привет", "к", "да", "ПРИВЕТ", "Привет", "хлеб", "обычный"])
    func russianInputIsKept(keys: String) {
        #expect(typedOnRussian(keys).decision == .keep)
    }

    @Test func wordsShorterThanThreeLettersAreKept() {
        #expect(typedOnEnglish("lf").decision == .keep)
        #expect(typedOnEnglish("yt").decision == .keep)
    }

    @Test func digitsPreventConversion() {
        #expect(typedOnEnglish("ghbdtn1").decision == .keep)
        #expect(typedOnEnglish("1ghbdtn").decision == .keep)
        #expect(typedOnEnglish("gh1bdtn").decision == .keep)
    }

    @Test func nonLetterInsideWordPreventsConversion() {
        #expect(typedOnEnglish("ghb/dtn").decision == .keep)
        #expect(typedOnEnglish("ghb!dtn").decision == .keep)
    }

    @Test func mixedCaseInsideWordPreventsConversion() {
        #expect(typedOnEnglish("ghBdtn").decision == .keep)
        #expect(typedOnEnglish("gHbdtn").decision == .keep)
    }

    @Test func capsLockCountsAsAllUppercase() {
        let strokes = Fixtures.capsLocked(Fixtures.strokes("ghbdtn", on: english))
        let verdict = detector.evaluate(strokes: strokes, current: english, alternate: russian)
        #expect(verdict.decision == .convert("ПРИВЕТ"))
    }

    @Test func hyphenInsideWordIsAllowed() {
        #expect(typedOnEnglish("rfr-nj").decision == .convert("как-то"))
        #expect(typedOnRussian("цудд-лтщцт").decision == .convert("well-known"))
    }

    @Test func leadingPunctuationIsKeptAndWordConverted() {
        #expect(typedOnEnglish("(ghbdtn").decision == .convert("(привет"))
    }

    @Test func trailingPunctuationOnPunctuationOnlyKeysFollowsTheAlternateLayout() {
        #expect(typedOnEnglish("ghbdtn!").decision == .convert("привет!"))
        #expect(typedOnEnglish("ghbdtn/").decision == .convert("привет."))
    }

    @Test func exceptionsPreventConversion() {
        let list = ExceptionList(words: ["ghbdtn"])
        let verdict = detector.evaluate(
            strokes: Fixtures.strokes("ghbdtn", on: english),
            current: english,
            alternate: russian,
            exceptions: list
        )
        #expect(verdict.decision == .keep)
        #expect(verdict.exceptionKey == "ghbdtn")
    }

    @Test func exceptionMatchesIgnoringCaseAndTrailingPunctuation() {
        let list = ExceptionList(words: ["ghbdtn"])
        for keys in ["Ghbdtn", "GHBDTN", "ghbdtn,"] {
            let verdict = detector.evaluate(
                strokes: Fixtures.strokes(keys, on: english),
                current: english,
                alternate: russian,
                exceptions: list
            )
            #expect(verdict.decision == .keep)
        }
    }

    @Test func verdictCarriesScoresAndExceptionKey() {
        let verdict = typedOnEnglish("ghbdtn")
        #expect(verdict.exceptionKey == "ghbdtn")
        #expect(verdict.alternateScore! > verdict.currentScore! + DetectorConfiguration.standard.margin)
    }

    @Test func lexiconSayingCurrentIsAWordBlocksConversion() {
        let lexicon = StubLexicon(words: ["en": ["ghbdtn"]])
        let guarded = WordDetector(lexicon: lexicon)
        let verdict = guarded.evaluate(strokes: Fixtures.strokes("ghbdtn", on: english), current: english, alternate: russian)
        #expect(verdict.decision == .keep)
    }

    @Test func lexiconConfirmingAlternateLowersTheMargin() {
        let strokes = Fixtures.strokes("ghbdtn", on: english)
        let strict = DetectorConfiguration(margin: 100, floor: -50, lexiconMarginReduction: 0, minimumLetters: 3)
        #expect(WordDetector(configuration: strict).evaluate(strokes: strokes, current: english, alternate: russian).decision == .keep)
        let reducing = DetectorConfiguration(margin: 100, floor: -50, lexiconMarginReduction: 100, minimumLetters: 3)
        let lexicon = StubLexicon(words: ["ru": ["привет"]])
        let verdict = WordDetector(configuration: reducing, lexicon: lexicon).evaluate(strokes: strokes, current: english, alternate: russian)
        #expect(verdict.decision == .convert("привет"))
    }

    @Test func lexiconWithoutOpinionChangesNothing() {
        let silent = WordDetector(lexicon: StubLexicon(words: [:]))
        let verdict = silent.evaluate(strokes: Fixtures.strokes("ghbdtn", on: english), current: english, alternate: russian)
        #expect(verdict.decision == .convert("привет"))
    }

    @Test func floorBlocksConversionToImprobableText() {
        let picky = DetectorConfiguration(margin: 0, floor: 5, lexiconMarginReduction: 0, minimumLetters: 3)
        let verdict = WordDetector(configuration: picky).evaluate(
            strokes: Fixtures.strokes("ghbdtn", on: english),
            current: english,
            alternate: russian
        )
        #expect(verdict.decision == .keep)
    }

    @Test func unmappedStrokesAreKept() {
        let strokes = [KeyStroke(keyCode: 0), KeyStroke(keyCode: 200), KeyStroke(keyCode: 1)]
        #expect(detector.evaluate(strokes: strokes, current: english, alternate: russian).decision == .keep)
    }

    @Test func emptyStrokesAreKept() {
        #expect(detector.evaluate(strokes: [], current: english, alternate: russian).decision == .keep)
    }

    @Test func forcedConversionIgnoresRules() {
        let strokes = Fixtures.strokes("ok", on: english)
        #expect(detector.convert(strokes: strokes, current: english, alternate: russian) == "щл")
        let digits = Fixtures.strokes("ghbdtn1", on: english)
        #expect(detector.convert(strokes: digits, current: english, alternate: russian) == "привет1")
        let mixed = Fixtures.strokes("ghBdtn", on: english)
        #expect(detector.convert(strokes: mixed, current: english, alternate: russian) == "прИвет")
    }

    @Test func forcedConversionKeepsTrailingCommaWhenWordIsBetterWithoutIt() {
        let strokes = Fixtures.strokes("ghbdtn,", on: english)
        #expect(detector.convert(strokes: strokes, current: english, alternate: russian) == "привет,")
    }

    @Test func forcedConversionOfEmptyIsNil() {
        #expect(detector.convert(strokes: [], current: english, alternate: russian) == nil)
    }

    @Test func forcedConversionWithoutLettersMapsEverything() {
        let strokes = Fixtures.strokes("123", on: english)
        #expect(detector.convert(strokes: strokes, current: english, alternate: russian) == "123")
    }

    @Test func forcedConversionFallsBackToPlainMappingWhenNoLetters() {
        let strokes = Fixtures.strokes("!?", on: english)
        let expected = russian.keyMap.text(for: strokes)
        #expect(detector.convert(strokes: strokes, current: english, alternate: russian) == expected)
    }

    @Test func appleRussianLayoutAlsoConverts() {
        let apple = Fixtures.russian
        let verdict = detector.evaluate(strokes: Fixtures.strokes("ghbdtn", on: english), current: english, alternate: apple)
        #expect(verdict.decision == .convert("привет"))
    }
}
