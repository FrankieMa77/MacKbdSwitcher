import Foundation
import Testing
@testable import KbdCore

@Suite struct ExceptionListTests {
    @Test func addsAndFindsWords() {
        let list = ExceptionList()
        list.add("ghbdtn")
        #expect(list.contains("ghbdtn"))
        #expect(!list.contains("other"))
        #expect(list.words == ["ghbdtn"])
    }

    @Test func ignoresEmptyAndDuplicateWords() {
        let list = ExceptionList()
        var changes = 0
        list.onChange = { _ in changes += 1 }
        list.add("")
        list.add("a")
        list.add("a")
        #expect(list.count == 1)
        #expect(changes == 1)
    }

    @Test func dropsOldestWordsBeyondTheLimit() {
        let list = ExceptionList(limit: 3)
        for word in ["a", "b", "c", "d"] {
            list.add(word)
        }
        #expect(list.words == ["b", "c", "d"])
        #expect(!list.contains("a"))
    }

    @Test func defaultLimitIsOneThousand() {
        let list = ExceptionList()
        for index in 0..<1200 {
            list.add("w\(index)")
        }
        #expect(list.count == 1000)
        #expect(list.contains("w1199"))
        #expect(!list.contains("w100"))
    }

    @Test func initialWordsAreTrimmedToTheLimit() {
        let list = ExceptionList(words: ["a", "b", "c"], limit: 2)
        #expect(list.words == ["b", "c"])
        #expect(list.contains("b"))
        #expect(!list.contains("a"))
    }

    @Test func clearRemovesEverythingAndNotifies() {
        let list = ExceptionList(words: ["a", "b"])
        var received: [[String]] = []
        list.onChange = { received.append($0) }
        list.clear()
        #expect(list.count == 0)
        #expect(!list.contains("a"))
        #expect(received == [[]])
    }

    @Test func clearOnEmptyListDoesNotNotify() {
        let list = ExceptionList()
        var changes = 0
        list.onChange = { _ in changes += 1 }
        list.clear()
        #expect(changes == 0)
    }

    @Test func onChangeReceivesTheUpdatedWords() {
        let list = ExceptionList()
        var received: [[String]] = []
        list.onChange = { received.append($0) }
        list.add("a")
        list.add("b")
        #expect(received == [["a"], ["a", "b"]])
    }
}

@Suite struct KeyKindTests {
    @Test func spaceReturnEnterAndTabAreBoundaries() {
        #expect(KeyKind.classify(keyCode: 49) == .boundary(" "))
        #expect(KeyKind.classify(keyCode: 36) == .boundary("\n"))
        #expect(KeyKind.classify(keyCode: 76) == .boundary("\n"))
        #expect(KeyKind.classify(keyCode: 48) == .boundary("\t"))
    }

    @Test func deleteIsBackspace() {
        #expect(KeyKind.classify(keyCode: 51) == .backspace)
    }

    @Test func typingKeysAreCharacters() {
        for keyCode: UInt16 in [0, 1, 12, 18, 27, 33, 41, 43, 47, 50] {
            #expect(KeyKind.classify(keyCode: keyCode) == .character)
        }
    }

    @Test func navigationAndEditingKeysReset() {
        let resetting: [UInt16] = [53, 117, 115, 119, 116, 121, 123, 124, 125, 126, 122, 120, 63, 82, 96, 114]
        for keyCode in resetting {
            #expect(KeyKind.classify(keyCode: keyCode) == .reset, "key code \(keyCode)")
        }
    }

    @Test func everyKeyCodeBelowFiftyOneIsClassifiedAsTypingOrBoundary() {
        for keyCode in UInt16(0)...50 {
            let kind = KeyKind.classify(keyCode: keyCode)
            #expect(kind != .reset && kind != .backspace)
        }
    }
}

@Suite struct TextChunksTests {
    @Test func shortTextIsOneChunk() {
        #expect(TextChunks.split("привет", limit: 20) == ["привет"])
    }

    @Test func emptyTextHasNoChunks() {
        #expect(TextChunks.split("", limit: 20).isEmpty)
    }

    @Test func longTextIsSplitWithinTheLimit() {
        let text = String(repeating: "я", count: 45)
        let chunks = TextChunks.split(text, limit: 20)
        #expect(chunks.map { $0.utf16.count } == [20, 20, 5])
        #expect(chunks.joined() == text)
    }

    @Test func surrogatePairsAreNeverSeparated() {
        let text = String(repeating: "😀", count: 7)
        let chunks = TextChunks.split(text, limit: 5)
        #expect(chunks.allSatisfy { $0.utf16.count <= 5 })
        #expect(chunks.joined() == text)
        #expect(chunks.allSatisfy { $0.count == $0.unicodeScalars.count })
    }

    @Test func combiningMarksStayWithTheirBase() {
        let text = String(repeating: "e\u{301}", count: 12)
        let chunks = TextChunks.split(text, limit: 5)
        #expect(chunks.joined() == text)
        #expect(chunks.allSatisfy { $0.first != "\u{301}" })
    }

    @Test func exactLimitFitsInOneChunk() {
        let text = String(repeating: "a", count: 20)
        #expect(TextChunks.split(text, limit: 20) == [text])
    }
}

@Suite struct ExcludedAppsTests {
    @Test func defaultsCoverCommonTerminals() {
        let defaults = ExcludedApps.defaults
        #expect(defaults.contains("com.apple.Terminal"))
        #expect(defaults.contains("com.googlecode.iterm2"))
        #expect(defaults.contains("dev.warp.Warp-Stable"))
        #expect(defaults.contains("com.mitchellh.ghostty"))
        #expect(defaults.contains("org.alacritty"))
        #expect(defaults.contains("net.kovidgoyal.kitty"))
        #expect(Set(defaults).count == defaults.count)
    }
}

@Suite struct LayoutProfileTests {
    @Test func languageComesFromTheModel() {
        #expect(Fixtures.english.language == "en")
        #expect(Fixtures.russianWin.language == "ru")
        #expect(Fixtures.russianWin.keyMap.id == Fixtures.russianWin.id)
    }
}

@Suite struct KeyStrokeTests {
    @Test func strokesCompareByAllFields() {
        #expect(KeyStroke(keyCode: 1) == KeyStroke(keyCode: 1, shift: false, capsLock: false))
        #expect(KeyStroke(keyCode: 1) != KeyStroke(keyCode: 1, shift: true))
        #expect(KeyStroke(keyCode: 1) != KeyStroke(keyCode: 1, capsLock: true))
        #expect(Set([KeyStroke(keyCode: 1), KeyStroke(keyCode: 1)]).count == 1)
    }
}
