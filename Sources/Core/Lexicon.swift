import Foundation

public protocol Lexicon {
    func contains(_ word: String, language: String) -> Bool?
}
