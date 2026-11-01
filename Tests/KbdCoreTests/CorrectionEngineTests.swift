import Foundation
import Testing
@testable import KbdCore

final class SpyExceptions: ExceptionStore {
    var added: [String] = []
    var known: Set<String> = []

    func contains(_ word: String) -> Bool {
        known.contains(word)
    }

    func add(_ word: String) {
        added.append(word)
        known.insert(word)
    }
}

struct Typist {
    let engine: CorrectionEngine
    var context: EngineContext?

    @discardableResult
    func type(_ keys: String, on profile: LayoutProfile = Fixtures.english) -> [EngineAction] {
        Fixtures.strokes(keys, on: profile).map { engine.handle(.key($0), context: context) }
    }

    @discardableResult
    func send(_ event: EngineEvent) -> EngineAction {
        engine.handle(event, context: context)
    }

    func space() -> EngineAction {
        send(.boundary(" "))
    }
}

func makeTypist(enabled: Bool = true, exceptions: ExceptionStore = SpyExceptions()) -> Typist {
    let engine = CorrectionEngine(detector: WordDetector(), exceptions: exceptions)
    let context = EngineContext(current: Fixtures.english, alternate: Fixtures.russianWin, enabled: enabled)
    return Typist(engine: engine, context: context)
}

let russianID = Fixtures.russianWin.id
let englishID = Fixtures.english.id

@Suite struct CorrectionEngineTests {
    @Test func keysPassThroughWhileBuffering() {
        let typist = makeTypist()
        let actions = typist.type("ghbdtn")
        #expect(actions.allSatisfy { $0 == .passThrough })
        #expect(typist.engine.pendingWordLength == 6)
    }

    @Test func wrongLayoutWordIsReplacedAtSpace() {
        let typist = makeTypist()
        typist.type("ghbdtn")
        #expect(typist.space() == .replace(deleteCount: 6, text: "привет ", switchTo: russianID))
        #expect(typist.engine.pendingWordLength == 0)
    }

    @Test func returnAndTabAreBoundariesToo() {
        let first = makeTypist()
        first.type("ghbdtn")
        #expect(first.send(.boundary("\n")) == .replace(deleteCount: 6, text: "привет\n", switchTo: russianID))
        let second = makeTypist()
        second.type("ghbdtn")
        #expect(second.send(.boundary("\t")) == .replace(deleteCount: 6, text: "привет\t", switchTo: russianID))
    }

    @Test func correctWordPassesThrough() {
        let typist = makeTypist()
        typist.type("hello")
        #expect(typist.space() == .passThrough)
    }

    @Test func shortWordPassesThrough() {
        let typist = makeTypist()
        typist.type("lf")
        #expect(typist.space() == .passThrough)
    }

    @Test func boundaryWithEmptyBufferPassesThrough() {
        let typist = makeTypist()
        #expect(typist.space() == .passThrough)
    }

    @Test func backspaceRemovesFromBuffer() {
        let typist = makeTypist()
        typist.type("ghbdtnx")
        #expect(typist.send(.backspace) == .passThrough)
        #expect(typist.engine.pendingWordLength == 6)
        #expect(typist.space() == .replace(deleteCount: 6, text: "привет ", switchTo: russianID))
    }

    @Test func backspaceOnEmptyBufferPassesThrough() {
        let typist = makeTypist()
        #expect(typist.send(.backspace) == .passThrough)
        #expect(typist.engine.pendingWordLength == 0)
    }

    @Test func resetDropsTheBufferWithoutDecision() {
        let typist = makeTypist()
        typist.type("ghbdtn")
        #expect(typist.send(.reset) == .passThrough)
        #expect(typist.engine.pendingWordLength == 0)
        #expect(typist.space() == .passThrough)
    }

    @Test func unexpectedLayoutChangeDropsTheBuffer() {
        let typist = makeTypist()
        typist.type("ghbdtn")
        #expect(typist.send(.layoutChanged(russianID)) == .passThrough)
        #expect(typist.space() == .passThrough)
    }

    @Test func missingContextDropsTheBufferAndNeverConverts() {
        var typist = makeTypist()
        typist.type("ghb")
        typist.context = nil
        typist.type("dtn")
        #expect(typist.engine.pendingWordLength == 0)
        #expect(typist.space() == .passThrough)
        #expect(typist.send(.forceConvert) == .passThrough)
    }

    @Test func switchingContextLayoutMidWordDropsEarlierKeys() {
        var typist = makeTypist()
        typist.type("ghb")
        typist.context = EngineContext(current: Fixtures.russianWin, alternate: Fixtures.english, enabled: true)
        typist.type("руд", on: Fixtures.russianWin)
        #expect(typist.engine.pendingWordLength == 3)
    }

    @Test func bufferFromAnotherLayoutIsNotConvertedAtBoundary() {
        var typist = makeTypist()
        typist.type("ghbdtn")
        typist.context = EngineContext(current: Fixtures.russianWin, alternate: Fixtures.english, enabled: true)
        #expect(typist.space() == .passThrough)
    }

    @Test func overlongWordIsIgnoredUntilTheNextBoundary() {
        let typist = makeTypist()
        typist.type(String(repeating: "g", count: CorrectionEngine.maximumWordLength + 5))
        #expect(typist.engine.pendingWordLength == 0)
        #expect(typist.space() == .passThrough)
        typist.type("ghbdtn")
        #expect(typist.space() == .replace(deleteCount: 6, text: "привет ", switchTo: russianID))
    }

    @Test func disabledModeNeverReplaces() {
        let typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        #expect(typist.space() == .passThrough)
    }

    @Test func backspaceRightAfterReplacementUndoesIt() {
        let exceptions = SpyExceptions()
        let typist = makeTypist(exceptions: exceptions)
        typist.type("ghbdtn")
        typist.space()
        #expect(typist.send(.backspace) == .replace(deleteCount: 7, text: "ghbdtn ", switchTo: englishID))
        #expect(exceptions.added == ["ghbdtn"])
    }

    @Test func undoneWordIsNotConvertedAgain() {
        let typist = makeTypist(exceptions: ExceptionList())
        typist.type("ghbdtn")
        typist.space()
        typist.send(.backspace)
        typist.send(.layoutChanged(englishID))
        typist.type("ghbdtn")
        #expect(typist.space() == .passThrough)
    }

    @Test func undoWindowClosesOnTheNextKey() {
        let exceptions = SpyExceptions()
        let typist = makeTypist(exceptions: exceptions)
        typist.type("ghbdtn")
        typist.space()
        typist.type("x")
        #expect(typist.send(.backspace) == .passThrough)
        #expect(exceptions.added.isEmpty)
    }

    @Test func undoWindowClosesOnReset() {
        let exceptions = SpyExceptions()
        let typist = makeTypist(exceptions: exceptions)
        typist.type("ghbdtn")
        typist.space()
        typist.send(.reset)
        #expect(typist.send(.backspace) == .passThrough)
        #expect(exceptions.added.isEmpty)
    }

    @Test func undoWindowClosesOnAnotherBoundary() {
        let exceptions = SpyExceptions()
        let typist = makeTypist(exceptions: exceptions)
        typist.type("ghbdtn")
        typist.space()
        typist.space()
        #expect(typist.send(.backspace) == .passThrough)
        #expect(exceptions.added.isEmpty)
    }

    @Test func layoutChangeCausedByTheReplacementKeepsTheUndoWindow() {
        let typist = makeTypist()
        typist.type("ghbdtn")
        typist.space()
        typist.send(.layoutChanged(russianID))
        #expect(typist.send(.backspace) == .replace(deleteCount: 7, text: "ghbdtn ", switchTo: englishID))
    }

    @Test func manualLayoutChangeClosesTheUndoWindow() {
        let typist = makeTypist()
        typist.type("ghbdtn")
        typist.space()
        typist.send(.layoutChanged("com.apple.keylayout.German"))
        #expect(typist.send(.backspace) == .passThrough)
    }

    @Test func undoWorksWhileTheSystemStillReportsTheOldLayout() {
        let typist = makeTypist()
        typist.type("ghbdtn")
        typist.space()
        let action = typist.send(.backspace)
        #expect(action == .replace(deleteCount: 7, text: "ghbdtn ", switchTo: englishID))
    }

    @Test func returnReplacementIsNotUndoable() {
        let exceptions = SpyExceptions()
        let typist = makeTypist(exceptions: exceptions)
        typist.type("ghbdtn")
        typist.send(.boundary("\n"))
        #expect(typist.send(.backspace) == .passThrough)
        #expect(exceptions.added.isEmpty)
    }

    @Test func forceConvertsTheCurrentBuffer() {
        let typist = makeTypist()
        typist.type("ghbdt")
        #expect(typist.send(.forceConvert) == .replace(deleteCount: 5, text: "приве", switchTo: russianID))
        #expect(typist.engine.pendingWordLength == 0)
    }

    @Test func forceConvertsEvenWhenDisabled() {
        let typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        #expect(typist.send(.forceConvert) == .replace(deleteCount: 6, text: "привет", switchTo: russianID))
    }

    @Test func forceConvertsTheLastCompletedWordAndItsBoundary() {
        let typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        typist.space()
        #expect(typist.send(.forceConvert) == .replace(deleteCount: 7, text: "привет ", switchTo: russianID))
    }

    @Test func forceConvertsACorrectlyTypedWordToo() {
        let typist = makeTypist()
        typist.type("hello")
        typist.space()
        #expect(typist.send(.forceConvert) == .replace(deleteCount: 6, text: "руддщ ", switchTo: russianID))
    }

    @Test func forceRightAfterAutoReplacementUndoesAndLearns() {
        let exceptions = SpyExceptions()
        let typist = makeTypist(exceptions: exceptions)
        typist.type("ghbdtn")
        typist.space()
        #expect(typist.send(.forceConvert) == .replace(deleteCount: 7, text: "ghbdtn ", switchTo: englishID))
        #expect(exceptions.added == ["ghbdtn"])
    }

    @Test func forceAfterUndoConvertsAgain() {
        let typist = makeTypist()
        typist.type("ghbdtn")
        typist.space()
        typist.send(.backspace)
        typist.send(.layoutChanged(englishID))
        #expect(typist.send(.forceConvert) == .replace(deleteCount: 7, text: "привет ", switchTo: russianID))
    }

    @Test func forceWithNothingNearbyPassesThrough() {
        let typist = makeTypist()
        #expect(typist.send(.forceConvert) == .passThrough)
    }

    @Test func forceAfterTypingMoreWordsAffectsOnlyTheNewestState() {
        let typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        typist.space()
        typist.type("x")
        #expect(typist.send(.forceConvert) == .replace(deleteCount: 1, text: "ч", switchTo: russianID))
    }

    @Test func forceDoesNotReachBackAcrossAnotherBoundary() {
        let typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        typist.space()
        typist.space()
        #expect(typist.send(.forceConvert) == .passThrough)
    }

    @Test func forceDoesNotReachBackAfterReturn() {
        let typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        typist.send(.boundary("\n"))
        #expect(typist.send(.forceConvert) == .passThrough)
    }

    @Test func forceDoesNotReachBackAfterLayoutChange() {
        let typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        typist.space()
        typist.send(.layoutChanged("com.apple.keylayout.German"))
        #expect(typist.send(.forceConvert) == .passThrough)
    }

    @Test func forceDoesNotReachBackAfterBackspace() {
        let typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        typist.space()
        typist.send(.backspace)
        #expect(typist.send(.forceConvert) == .passThrough)
    }

    @Test func forceOnCompletedWordFromAnotherLayoutPassesThrough() {
        var typist = makeTypist(enabled: false)
        typist.type("ghbdtn")
        typist.space()
        typist.context = EngineContext(current: Fixtures.russianWin, alternate: Fixtures.english, enabled: false)
        #expect(typist.send(.forceConvert) == .passThrough)
    }

    @Test func exceptionsLearnedByUndoSurviveThroughTheList() {
        let list = ExceptionList()
        let typist = makeTypist(exceptions: list)
        typist.type("ghbdtn")
        typist.space()
        typist.send(.backspace)
        #expect(list.contains("ghbdtn"))
        #expect(list.count == 1)
    }

    @Test func existingExceptionStopsConversion() {
        let exceptions = SpyExceptions()
        exceptions.known = ["ghbdtn"]
        let typist = makeTypist(exceptions: exceptions)
        typist.type("ghbdtn")
        #expect(typist.space() == .passThrough)
    }

    @Test func englishWordsAreConvertedFromRussianLayoutBack() {
        var typist = makeTypist()
        typist.context = EngineContext(current: Fixtures.russianWin, alternate: Fixtures.english, enabled: true)
        typist.type("руддщ", on: Fixtures.russianWin)
        #expect(typist.space() == .replace(deleteCount: 5, text: "hello ", switchTo: englishID))
    }

    @Test func nextWordAfterReplacementIsTrackedInTheNewLayout() {
        var typist = makeTypist()
        typist.type("ghbdtn")
        typist.space()
        typist.send(.layoutChanged(russianID))
        typist.context = EngineContext(current: Fixtures.russianWin, alternate: Fixtures.english, enabled: true)
        typist.type("руддщ", on: Fixtures.russianWin)
        #expect(typist.space() == .replace(deleteCount: 5, text: "hello ", switchTo: englishID))
    }
}
