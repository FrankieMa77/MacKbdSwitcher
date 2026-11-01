import Foundation

public struct LanguageModel: Sendable {
    public let language: String
    public let unseen: Double
    private let logProbabilities: [String: Double]

    public static let defaultUnseen = -12.0

    public init(language: String, tsv: String) {
        var table: [String: Double] = [:]
        var unseen = LanguageModel.defaultUnseen
        for line in tsv.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 2, let value = Double(parts[1]) else { continue }
            if parts[0] == "unseen" {
                unseen = value
            } else {
                table[String(parts[0])] = value
            }
        }
        self.language = language
        self.unseen = unseen
        self.logProbabilities = table
    }

    public init(language: String, contentsOf url: URL) throws {
        self.init(language: language, tsv: try String(contentsOf: url, encoding: .utf8))
    }

    public var trigramCount: Int {
        logProbabilities.count
    }

    public func logProbability(of trigram: String) -> Double? {
        logProbabilities[trigram]
    }

    public func score(_ word: String) -> Double {
        var total = 0.0
        var count = 0
        for segment in word.lowercased().split(separator: "-") {
            let characters = Array("^" + segment + "$")
            guard characters.count >= 3 else { continue }
            for index in 0...(characters.count - 3) {
                total += logProbabilities[String(characters[index..<index + 3])] ?? unseen
                count += 1
            }
        }
        return count == 0 ? unseen : total / Double(count)
    }
}
