import Foundation
import Testing
@testable import KbdCore

@Suite struct KeyMapOptionLayerTests {
    let polish = Fixtures.keyMap("PolishPro")
    let us = Fixtures.keyMap("US")
    let russianWin = Fixtures.keyMap("RussianWin")

    @Test func optionLayerProducesPolishLetters() {
        let expected: [UInt16: String] = [0: "ą", 6: "ż", 7: "ź", 8: "ć", 31: "ó", 45: "ń"]
        for (keyCode, letter) in expected {
            #expect(polish.character(for: KeyStroke(keyCode: keyCode, option: true)) == letter)
        }
        #expect(polish.character(for: KeyStroke(keyCode: 0, shift: true, option: true)) == "Ą")
        #expect(polish.character(for: KeyStroke(keyCode: 0, capsLock: true, option: true)) == "Ą")
    }

    @Test func optionLayerIsSeparateFromTheBaseLayer() {
        #expect(polish.character(for: KeyStroke(keyCode: 0)) == "a")
        #expect(us.character(for: KeyStroke(keyCode: 0, option: true)) != "a")
    }

    @Test func reverseLookupPrefersBaseLayerThenOption() {
        #expect(polish.stroke(for: "a") == KeyStroke(keyCode: 0))
        #expect(polish.stroke(for: "ą") == KeyStroke(keyCode: 0, option: true))
        #expect(polish.stroke(for: "Ą") == KeyStroke(keyCode: 0, shift: true, option: true))
    }

    @Test func textTranslatesOptionStrokes() {
        let strokes = Fixtures.strokes("zażółć", on: Fixtures.polishPro)
        #expect(polish.text(for: strokes) == "zażółć")
        #expect(strokes.filter(\.option).count == 4)
    }

    @Test func alphabetComesFromTheMainKeys() {
        #expect(us.alphabet == .latin)
        #expect(polish.alphabet == .latin)
        #expect(russianWin.alphabet == .cyrillic)
        #expect(Fixtures.keyMap("Russian").alphabet == .cyrillic)
    }

    @Test func layoutWithoutLettersHasNoAlphabet() {
        let digits = KeyMap(id: "digits", table: Dictionary(uniqueKeysWithValues: (0..<12).map { (UInt16($0), [String?(String($0 % 10))]) }))
        #expect(digits.alphabet == nil)
    }

    @Test func eightColumnRowsRoundTripThroughJson() throws {
        let json = Data(#"{"id":"t","keys":{"0":["a","A","A","A","ą","Ą","Ą","Ą"]}}"#.utf8)
        let map = try KeyMap(json: json)
        #expect(map.character(for: KeyStroke(keyCode: 0, option: true)) == "ą")
    }

    @Test func strokesWithDifferentOptionFlagsAreDistinct() {
        #expect(KeyStroke(keyCode: 1) != KeyStroke(keyCode: 1, option: true))
        #expect(KeyStroke(keyCode: 1).option == false)
    }
}

@Suite struct LayoutLanguagesTests {
    let all: Set<String> = ["en", "pl", "ru"]

    func resolve(_ system: [String], _ alphabet: Alphabet, available: Set<String>? = nil, override: [String]? = nil) -> [String] {
        LayoutLanguages.resolve(systemLanguages: system, alphabet: alphabet, available: available ?? all, override: override)
    }

    @Test func polishLatinLayoutDefaultsToPolishAndEnglish() {
        #expect(resolve(["pl", "en"], .latin) == ["en", "pl"])
    }

    @Test func englishLatinLayoutDefaultsToEnglishOnly() {
        #expect(resolve(["en"], .latin) == ["en"])
    }

    @Test func cyrillicLayoutDefaultsToItsPrimaryLanguage() {
        #expect(resolve(["ru", "en"], .cyrillic) == ["ru"])
    }

    @Test func latinLayoutOfAnUnsupportedLanguageFallsBackToEnglish() {
        #expect(resolve(["de"], .latin) == ["en"])
    }

    @Test func unsupportedCyrillicLanguageGivesNothing() {
        #expect(resolve(["uk"], .cyrillic).isEmpty)
    }

    @Test func languageWithoutModelIsDropped() {
        #expect(resolve(["pl"], .latin, available: ["pl", "ru"]) == ["pl"])
        #expect(resolve(["pl"], .latin, available: ["en", "ru"]) == ["en"])
        #expect(resolve(["de"], .latin, available: ["pl", "ru"]).isEmpty)
        #expect(resolve(["ru"], .cyrillic, available: ["en", "pl"]).isEmpty)
    }

    @Test func primaryLanguageOfAnotherAlphabetIsIgnored() {
        #expect(resolve(["pl"], .cyrillic).isEmpty)
        #expect(resolve(["ru"], .latin) == ["en"])
    }

    @Test func regionSuffixesAreNormalized() {
        #expect(resolve(["pl-PL"], .latin) == ["en", "pl"])
        #expect(LayoutLanguages.normalize("ru_RU") == "ru")
        #expect(LayoutLanguages.normalize("EN") == "en")
    }

    @Test func overrideReplacesTheDefault() {
        #expect(resolve(["pl"], .latin, override: ["pl"]) == ["pl"])
        #expect(resolve(["en"], .latin, override: ["en", "pl"]) == ["en", "pl"])
    }

    @Test func emptyOverrideExcludesTheLayout() {
        #expect(resolve(["pl"], .latin, override: []).isEmpty)
    }

    @Test func overrideDropsLanguagesThatDoNotFit() {
        #expect(resolve(["pl"], .latin, override: ["ru", "pl"]) == ["pl"])
        #expect(resolve(["pl"], .latin, override: ["ru"]).isEmpty)
        #expect(resolve(["pl"], .latin, available: ["en", "ru"], override: ["pl"]).isEmpty)
    }

    @Test func resultFollowsCatalogOrder() {
        #expect(resolve(["en"], .latin, override: ["pl", "en"]) == ["en", "pl"])
    }

    @Test func optionsListLanguagesOfTheAlphabet() {
        #expect(LayoutLanguages.options(for: .latin, available: all) == ["en", "pl"])
        #expect(LayoutLanguages.options(for: .cyrillic, available: all) == ["ru"])
        #expect(LayoutLanguages.options(for: .latin, available: ["pl"]) == ["pl"])
    }

    @Test func togglingRemovesAndAddsLanguages() {
        let allowed = ["en", "pl"]
        #expect(LayoutLanguages.toggled("pl", in: ["en", "pl"], allowed: allowed) == ["en"])
        #expect(LayoutLanguages.toggled("pl", in: ["en"], allowed: allowed) == ["en", "pl"])
        #expect(LayoutLanguages.toggled("en", in: ["en"], allowed: allowed).isEmpty)
        #expect(LayoutLanguages.toggled("en", in: [], allowed: allowed) == ["en"])
    }

    @Test func togglingAnUnknownLanguageChangesNothing() {
        #expect(LayoutLanguages.toggled("ru", in: ["en"], allowed: ["en", "pl"]) == ["en"])
    }

    @Test func newLanguageNeedsOnlyACatalogLine() {
        let catalog = SupportedLanguages.all + [LanguageInfo(code: "uk", name: "Українська", alphabet: .cyrillic)]
        #expect(LayoutLanguages.options(for: .cyrillic, available: ["ru", "uk"], catalog: catalog) == ["ru", "uk"])
        let resolved = LayoutLanguages.resolve(systemLanguages: ["uk"], alphabet: .cyrillic, available: ["ru", "uk"], override: nil, catalog: catalog)
        #expect(resolved == ["uk"])
    }

    @Test func catalogListsEnglishPolishRussian() {
        #expect(SupportedLanguages.all.map(\.code) == ["en", "pl", "ru"])
        #expect(SupportedLanguages.info(for: "pl")?.alphabet == .latin)
        #expect(SupportedLanguages.info(for: "ru")?.alphabet == .cyrillic)
        #expect(SupportedLanguages.info(for: "xx") == nil)
    }

    @Test func everySupportedLanguageHasAModelTable() {
        for language in SupportedLanguages.all {
            let model = Fixtures.model(language.code)
            #expect(model.trigramCount > 1000, "\(language.code)")
            #expect(model.language == language.code)
        }
    }
}

@Suite struct LayoutPairingTests {
    let us = Fixtures.english
    let polish = Fixtures.polishPro
    let russian = Fixtures.russianWin

    @Test func onlyLayoutsOfAnotherAlphabetAreCandidates() {
        let order = [us.id, polish.id, russian.id]
        #expect(LayoutPairing.alternates(current: us, among: [us, polish, russian], order: order).map(\.id) == [russian.id])
        #expect(LayoutPairing.alternates(current: polish, among: [us, polish, russian], order: order).map(\.id) == [russian.id])
        #expect(LayoutPairing.alternates(current: russian, among: [us, polish, russian], order: order).map(\.id) == [us.id, polish.id])
    }

    @Test func candidatesFollowRecentOrder() {
        let all = [us, polish, russian]
        #expect(LayoutPairing.alternates(current: russian, among: all, order: [russian.id, polish.id, us.id]).map(\.id) == [polish.id, us.id])
        #expect(LayoutPairing.alternates(current: russian, among: all, order: [russian.id, us.id, polish.id]).map(\.id) == [us.id, polish.id])
    }

    @Test func layoutsMissingFromTheOrderComeLastInGivenOrder() {
        let all = [us, polish, russian]
        #expect(LayoutPairing.alternates(current: russian, among: all, order: [polish.id]).map(\.id) == [polish.id, us.id])
        #expect(LayoutPairing.alternates(current: russian, among: all, order: []).map(\.id) == [us.id, polish.id])
    }

    @Test func sameAlphabetLayoutsAreNeverPaired() {
        #expect(LayoutPairing.alternates(current: us, among: [us, polish], order: []).isEmpty)
        #expect(LayoutPairing.alternates(current: russian, among: [russian, Fixtures.russian], order: []).isEmpty)
    }

    @Test func currentLayoutIsNeverItsOwnCandidate() {
        #expect(LayoutPairing.alternates(current: russian, among: [russian], order: []).isEmpty)
    }

    @Test func supportedPairNeedsTwoAlphabets() {
        #expect(LayoutPairing.hasSupportedPair(among: [us, russian]))
        #expect(LayoutPairing.hasSupportedPair(among: [polish, russian]))
        #expect(LayoutPairing.hasSupportedPair(among: [us, polish, russian]))
        #expect(!LayoutPairing.hasSupportedPair(among: [us, polish]))
        #expect(!LayoutPairing.hasSupportedPair(among: [russian, Fixtures.russian]))
        #expect(!LayoutPairing.hasSupportedPair(among: [us]))
        #expect(!LayoutPairing.hasSupportedPair(among: []))
    }

    @Test func layoutWithoutModelsDoesNotCountAsSupported() {
        let bare = LayoutProfile(id: "bare", keyMap: russian.keyMap, models: [])
        #expect(!LayoutPairing.hasSupportedPair(among: [us, bare]))
        #expect(LayoutPairing.alternates(current: us, among: [us, bare], order: []).isEmpty)
    }

    @Test func profileScoreIsTheBestOfItsModels() {
        let word = "dobry"
        let english = Fixtures.model("en").score(word)
        let polishScore = Fixtures.model("pl").score(word)
        #expect(polish.score(word) == max(english, polishScore))
        #expect(polish.languages == ["en", "pl"])
        #expect(polish.alphabet == .latin)
        #expect(russian.alphabet == .cyrillic)
    }
}

@Suite struct MultiLanguageDetectorTests {
    let detector = WordDetector()
    let us = Fixtures.english
    let polish = Fixtures.polishPro
    let russian = Fixtures.russianWin

    @Test func polishWordWithDiacriticsIsLeftAlone() {
        let strokes = Fixtures.strokes("zażółć", on: polish)
        #expect(detector.evaluate(strokes: strokes, current: polish, alternate: russian).decision == .keep)
        #expect(detector.evaluate(strokes: strokes, current: polish, alternates: [russian, us]).decision == .keep)
    }

    @Test func polishWordsWithDiacriticsAreKeptAcrossTheCorpusSample() {
        for word in ["być", "się", "więc", "żeby", "mógł", "dziękuję", "zażółć", "gęślą", "jaźń"] {
            let strokes = Fixtures.strokes(word, on: polish)
            #expect(detector.evaluate(strokes: strokes, current: polish, alternate: russian).decision == .keep, "\(word)")
        }
    }

    @Test func russianKeysOnPolishLayoutBecomeRussian() {
        let strokes = Fixtures.strokes("ghbdtn", on: polish)
        let verdict = detector.evaluate(strokes: strokes, current: polish, alternate: russian)
        #expect(verdict.decision == .convert("привет"))
        #expect(verdict.alternateID == russian.id)
    }

    @Test func englishWordOnRussianLayoutBecomesEnglishWithPolishAlternate() {
        let strokes = Fixtures.strokes("руддщ", on: russian)
        let verdict = detector.evaluate(strokes: strokes, current: russian, alternate: polish)
        #expect(verdict.decision == .convert("hello"))
        #expect(verdict.alternateID == polish.id)
    }

    @Test func polishWordWithoutDiacriticsOnRussianLayoutBecomesPolish() {
        let strokes = Fixtures.strokes("вщикн", on: russian)
        #expect(detector.evaluate(strokes: strokes, current: russian, alternate: polish).decision == .convert("dobry"))
    }

    @Test func polishOnlyWordIsConvertedOnlyWhenPolishIsAmongTheAlternateLanguages() {
        let strokes = Fixtures.strokes("wszystko", on: polish)
        #expect(detector.evaluate(strokes: strokes, current: russian, alternate: us).decision == .keep)
        #expect(detector.evaluate(strokes: strokes, current: russian, alternate: polish).decision == .convert("wszystko"))
    }

    @Test func englishWordIsKeptOnPolishLayoutWithEnglishLanguageEnabled() {
        let strokes = Fixtures.strokes("hello", on: polish)
        #expect(detector.evaluate(strokes: strokes, current: polish, alternate: russian).decision == .keep)
    }

    @Test func englishWordWouldBeConvertedWhenOnlyPolishIsEnabledOnTheLayout() {
        let polishOnly = LayoutProfile(id: polish.id, keyMap: polish.keyMap, models: [Fixtures.model("pl")])
        let strokes = Fixtures.strokes("thanks", on: polishOnly)
        let withBoth = detector.evaluate(strokes: strokes, current: polish, alternate: russian)
        let without = detector.evaluate(strokes: strokes, current: polishOnly, alternate: russian)
        #expect(withBoth.decision == .keep)
        #expect(without.currentScore! < withBoth.currentScore!)
    }

    @Test func bestScoringAlternateWins() {
        let strokes = Fixtures.strokes("ghbdtn", on: us)
        let cyrillicOther = Fixtures.russian
        let verdict = detector.evaluate(strokes: strokes, current: us, alternates: [cyrillicOther, russian])
        #expect(verdict.decision == .convert("привет"))
        #expect(verdict.alternateID == cyrillicOther.id)
    }

    @Test func identicalCandidatesResolveToTheMoreRecentOne() {
        let copy = Fixtures.clone(of: us, id: "copy")
        let strokes = Fixtures.strokes("руддщ", on: russian)
        let first = detector.evaluate(strokes: strokes, current: russian, alternates: [copy, us])
        let second = detector.evaluate(strokes: strokes, current: russian, alternates: [us, copy])
        #expect(first.alternateID == copy.id)
        #expect(second.alternateID == us.id)
    }

    @Test func aConvertingCandidateBeatsAKeepingOne() {
        let strokes = Fixtures.strokes("ghbdtn", on: us)
        let ruSecond = detector.evaluate(strokes: strokes, current: us, alternates: [us, russian])
        #expect(ruSecond.decision == .convert("привет"))
        #expect(ruSecond.alternateID == russian.id)
    }

    @Test func noAlternatesMeansKeep() {
        let strokes = Fixtures.strokes("ghbdtn", on: us)
        #expect(detector.evaluate(strokes: strokes, current: us, alternates: []).decision == .keep)
    }

    @Test func lexiconInAnyLanguageOfTheCurrentLayoutBlocksConversion() {
        let strokes = Fixtures.strokes("ghbdtn", on: polish)
        let polishWord = StubLexicon(words: ["pl": ["ghbdtn"]])
        let englishWord = StubLexicon(words: ["en": ["ghbdtn"]])
        let none = StubLexicon(words: ["ru": ["ghbdtn"]])
        #expect(WordDetector(lexicon: polishWord).evaluate(strokes: strokes, current: polish, alternate: russian).decision == .keep)
        #expect(WordDetector(lexicon: englishWord).evaluate(strokes: strokes, current: polish, alternate: russian).decision == .keep)
        #expect(WordDetector(lexicon: none).evaluate(strokes: strokes, current: polish, alternate: russian).decision == .convert("привет"))
    }

    @Test func lexiconInAnyLanguageOfTheAlternateLowersTheMargin() {
        let strokes = Fixtures.strokes("вщикн", on: russian)
        let reducing = DetectorConfiguration(margin: 100, floor: -50, lexiconMarginReduction: 100, minimumLetters: 3)
        let lexicon = StubLexicon(words: ["pl": ["dobry"]])
        let verdict = WordDetector(configuration: reducing, lexicon: lexicon).evaluate(strokes: strokes, current: russian, alternate: polish)
        #expect(verdict.decision == .convert("dobry"))
        let unconfirmed = WordDetector(configuration: reducing).evaluate(strokes: strokes, current: russian, alternate: polish)
        #expect(unconfirmed.decision == .keep)
    }

    @Test func optionLetterWithoutAlternateLetterBlocksConversion() {
        let key = Fixtures.optionOnlyKey(letterIn: polish.keyMap, notLetterIn: russian.keyMap)
        guard let key else {
            Issue.record("fixtures have no option letter that is not a letter in RussianWin")
            return
        }
        var strokes = Fixtures.strokes("ghbdt", on: polish)
        strokes.append(KeyStroke(keyCode: key, option: true))
        #expect(detector.evaluate(strokes: strokes, current: polish, alternate: russian).decision == .keep)
    }

    @Test func forcedConversionPicksTheBestAlternate() {
        let strokes = Fixtures.strokes("руддщ", on: russian)
        let forced = detector.convert(strokes: strokes, current: russian, alternates: [polish, us])
        #expect(forced?.text == "hello")
        #expect(forced?.alternateID == polish.id)
        let copy = Fixtures.clone(of: us, id: "copy")
        #expect(detector.convert(strokes: strokes, current: russian, alternates: [copy, us])?.alternateID == "copy")
    }

    @Test func forcedConversionWithoutAlternatesIsNil() {
        let strokes = Fixtures.strokes("руддщ", on: russian)
        #expect(detector.convert(strokes: strokes, current: russian, alternates: []) == nil)
    }

    @Test func forcedConversionOfOptionLettersUsesTheAlternateMap() {
        let strokes = Fixtures.strokes("ąę", on: polish)
        let forced = detector.convert(strokes: strokes, current: polish, alternates: [russian])
        #expect(forced?.text == russian.keyMap.text(for: strokes))
    }
}

@Suite struct MultiLanguageEngineTests {
    let us = Fixtures.english
    let polish = Fixtures.polishPro
    let russian = Fixtures.russianWin

    func typist(current: LayoutProfile, alternates: [LayoutProfile], enabled: Bool = true) -> Typist {
        let engine = CorrectionEngine(detector: WordDetector(), exceptions: SpyExceptions())
        return Typist(engine: engine, context: EngineContext(current: current, alternates: alternates, enabled: enabled))
    }

    @Test func switchTargetIsTheChosenAlternate() {
        let first = typist(current: russian, alternates: [polish, us])
        first.type("руддщ", on: russian)
        #expect(first.space() == .replace(deleteCount: 5, text: "hello ", switchTo: polish.id))
        let second = typist(current: russian, alternates: [us, polish])
        second.type("руддщ", on: russian)
        #expect(second.space() == .replace(deleteCount: 5, text: "hello ", switchTo: us.id))
    }

    @Test func polishLayoutConvertsRussianKeysToTheRussianLayout() {
        let session = typist(current: polish, alternates: [russian])
        session.type("ghbdtn", on: polish)
        #expect(session.space() == .replace(deleteCount: 6, text: "привет ", switchTo: russian.id))
    }

    @Test func polishWordWithDiacriticsPassesThroughOnPolishLayout() {
        let session = typist(current: polish, alternates: [russian])
        session.type("zażółć", on: polish)
        #expect(session.engine.pendingWordLength == 6)
        #expect(session.space() == .passThrough)
    }

    @Test func undoReturnsToTheOriginalLayoutWithSeveralAlternates() {
        let session = typist(current: russian, alternates: [polish, us])
        session.type("руддщ", on: russian)
        session.space()
        #expect(session.send(.backspace) == .replace(deleteCount: 6, text: "руддщ ", switchTo: russian.id))
    }

    @Test func forceConvertUsesTheBestAlternate() {
        let session = typist(current: russian, alternates: [polish, us], enabled: false)
        session.type("вщикн", on: russian)
        #expect(session.send(.forceConvert) == .replace(deleteCount: 5, text: "dobry", switchTo: polish.id))
    }

    @Test func optionKeyThatIsNotALetterResetsTheBuffer() {
        let session = typist(current: polish, alternates: [russian])
        guard let key = (UInt16(0)...50).first(where: { code in
            let character = polish.keyMap.character(for: KeyStroke(keyCode: code, option: true))
            return character != nil && !(character!.count == 1 && character!.first!.isLetter)
        }) else {
            Issue.record("no non-letter option key in PolishPro fixture")
            return
        }
        session.type("ghb", on: polish)
        session.send(.key(KeyStroke(keyCode: key, option: true)))
        #expect(session.engine.pendingWordLength == 0)
        session.type("dtn", on: polish)
        #expect(session.engine.pendingWordLength == 3)
    }

    @Test func optionKeyWithoutAnyCharacterResetsTheBuffer() {
        let session = typist(current: polish, alternates: [russian])
        session.type("ghb", on: polish)
        session.send(.key(KeyStroke(keyCode: 34, option: true)))
        #expect(session.engine.pendingWordLength == 0)
    }

    @Test func optionKeyThatIsALetterJoinsTheWord() {
        let session = typist(current: polish, alternates: [russian])
        session.send(.key(KeyStroke(keyCode: 0, option: true)))
        #expect(session.engine.pendingWordLength == 1)
    }

    @Test func emptyAlternatesDisableTheEngine() {
        let session = typist(current: us, alternates: [])
        session.type("ghbdtn", on: us)
        #expect(session.engine.pendingWordLength == 0)
        #expect(session.space() == .passThrough)
        #expect(session.send(.forceConvert) == .passThrough)
    }

    @Test func contextInitializerWithSingleAlternateWraps() {
        let context = EngineContext(current: us, alternate: russian, enabled: true)
        #expect(context.alternates.map(\.id) == [russian.id])
    }
}
