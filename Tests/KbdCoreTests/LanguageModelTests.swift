import Foundation
import Testing
@testable import KbdCore

@Suite struct LanguageModelTests {
    let tiny = LanguageModel(language: "xx", tsv: "unseen\t-9.0\n^ab\t-1.0\nab$\t-3.0\n^cd\t-2.0\n")

    @Test func parsesTrigramsAndUnseenValue() {
        #expect(tiny.trigramCount == 3)
        #expect(tiny.unseen == -9.0)
        #expect(tiny.logProbability(of: "^ab") == -1.0)
        #expect(tiny.logProbability(of: "zzz") == nil)
        #expect(tiny.language == "xx")
    }

    @Test func missingUnseenLineFallsBackToDefault() {
        let model = LanguageModel(language: "xx", tsv: "^ab\t-1.0\n")
        #expect(model.unseen == LanguageModel.defaultUnseen)
    }

    @Test func malformedLinesAreSkipped() {
        let model = LanguageModel(language: "xx", tsv: "garbage\n^ab\tnot-a-number\n^ab\t-1.0\n\n")
        #expect(model.trigramCount == 1)
    }

    @Test func scoreAveragesTrigramLogProbabilities() {
        #expect(tiny.score("ab") == -2.0)
    }

    @Test func unseenTrigramsUseTheSmoothingValue() {
        #expect(tiny.score("zz") == -9.0)
        #expect(tiny.score("abz") == (-1.0 + -9.0 + -9.0) / 3)
    }

    @Test func scoreIgnoresCase() {
        #expect(tiny.score("AB") == tiny.score("ab"))
    }

    @Test func hyphenSplitsWordIntoSegments() {
        #expect(tiny.score("ab-cd") == (-1.0 + -3.0 + -2.0 + -9.0) / 4)
    }

    @Test func emptyWordScoresAsUnseen() {
        #expect(tiny.score("") == tiny.unseen)
        #expect(tiny.score("-") == tiny.unseen)
    }

    @Test func loadsFromFile() throws {
        let url = Fixtures.repositoryRoot.appendingPathComponent("Resources/ngrams-en.tsv")
        let model = try LanguageModel(language: "en", contentsOf: url)
        #expect(model.trigramCount > 1000)
        #expect(model.unseen < -5)
    }

    @Test func missingFileThrows() {
        let url = URL(fileURLWithPath: "/nonexistent/ngrams.tsv")
        #expect(throws: (any Error).self) { try LanguageModel(language: "en", contentsOf: url) }
    }

    @Test func realWordsOutscoreKeyboardMash() {
        let english = Fixtures.model("en")
        let russian = Fixtures.model("ru")
        #expect(english.score("hello") > english.score("ghbdtn") + 2)
        #expect(russian.score("привет") > russian.score("руддщ") + 2)
        #expect(english.score("world") > english.score("цщкдв"))
    }

    @Test func englishModelKnowsApostrophes() {
        let english = Fixtures.model("en")
        #expect(english.score("don't") > english.score("dxn't"))
    }

    @Test func modelsDoNotContainTrainingCorpusWordsOnlyTrigramStatistics() {
        let russian = Fixtures.model("ru")
        #expect(russian.logProbability(of: "^пр") != nil)
        #expect(russian.logProbability(of: "ет$") != nil)
    }
}
