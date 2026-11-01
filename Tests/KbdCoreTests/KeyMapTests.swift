import Foundation
import Testing
@testable import KbdCore

@Suite struct KeyMapTests {
    let us = Fixtures.keyMap("US")
    let russianWin = Fixtures.keyMap("RussianWin")
    let russian = Fixtures.keyMap("Russian")

    @Test func fixturesCarryLayoutIdentifiers() {
        #expect(us.id == "com.apple.keylayout.US")
        #expect(russianWin.id == "com.apple.keylayout.RussianWin")
        #expect(russian.id == "com.apple.keylayout.Russian")
    }

    @Test func letterKeyProducesCaseFromShiftAndCapsLock() {
        #expect(us.character(for: KeyStroke(keyCode: 0)) == "a")
        #expect(us.character(for: KeyStroke(keyCode: 0, shift: true)) == "A")
        #expect(us.character(for: KeyStroke(keyCode: 0, capsLock: true)) == "A")
        #expect(russianWin.character(for: KeyStroke(keyCode: 0)) == "ф")
        #expect(russianWin.character(for: KeyStroke(keyCode: 0, shift: true)) == "Ф")
        #expect(russianWin.character(for: KeyStroke(keyCode: 0, capsLock: true)) == "Ф")
    }

    @Test func unknownKeyCodeHasNoCharacter() {
        #expect(us.character(for: KeyStroke(keyCode: 200)) == nil)
    }

    @Test func punctuationKeysThatAreLettersInRussian() {
        for keyCode: UInt16 in [43, 47, 41, 39, 33, 30] {
            #expect(!us.isLetter(keyCode: keyCode))
            #expect(russianWin.isLetter(keyCode: keyCode))
        }
    }

    @Test func letterKeysAreLettersInBothLayouts() {
        for keyCode: UInt16 in [0, 1, 2, 12, 13, 14] {
            #expect(us.isLetter(keyCode: keyCode))
            #expect(russianWin.isLetter(keyCode: keyCode))
        }
    }

    @Test func textTranslatesStrokesThroughTheMap() {
        let strokes = Fixtures.strokes("ghbdtn", on: Fixtures.english)
        #expect(us.text(for: strokes) == "ghbdtn")
        #expect(russianWin.text(for: strokes) == "привет")
    }

    @Test func textIsNilWhenAnyStrokeIsUnmapped() {
        let strokes = [KeyStroke(keyCode: 0), KeyStroke(keyCode: 200)]
        #expect(us.text(for: strokes) == nil)
    }

    @Test func reverseLookupFindsLowercaseThenShifted() {
        #expect(us.stroke(for: "a") == KeyStroke(keyCode: 0))
        #expect(us.stroke(for: "A") == KeyStroke(keyCode: 0, shift: true))
        #expect(russianWin.stroke(for: "ж") == KeyStroke(keyCode: 41))
        #expect(us.stroke(for: "ж") == nil)
    }

    @Test func appleAndWindowsRussianDifferOnPunctuationKeys() {
        let slash = KeyStroke(keyCode: 44)
        #expect(russian.character(for: slash) != russianWin.character(for: slash))
        #expect(russianWin.character(for: slash) == ".")
    }

    @Test func tableInitializerAndJsonAgree() throws {
        let json = Data(#"{"id":"test","keys":{"0":["a","A",null,"A"]}}"#.utf8)
        let decoded = try KeyMap(json: json)
        let manual = KeyMap(id: "test", table: [0: ["a", "A", nil, "A"]])
        #expect(decoded == manual)
        #expect(decoded.character(for: KeyStroke(keyCode: 0, capsLock: true)) == nil)
    }

    @Test func malformedJsonThrows() {
        #expect(throws: (any Error).self) { try KeyMap(json: Data("{".utf8)) }
        #expect(throws: (any Error).self) { try KeyMap(json: Data(#"{"id":"x","keys":{"zz":["a"]}}"#.utf8)) }
    }

    @Test func shortRowsReturnNilForMissingModifiers() {
        let map = KeyMap(id: "short", table: [0: ["a"]])
        #expect(map.character(for: KeyStroke(keyCode: 0)) == "a")
        #expect(map.character(for: KeyStroke(keyCode: 0, shift: true)) == nil)
    }
}
