import Foundation

let alphabets: [String: Set<Character>] = [
    "en": Set("abcdefghijklmnopqrstuvwxyz'"),
    "pl": Set("abcdefghijklmnopqrstuvwxyząćęłńóśźż"),
    "ru": Set("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"),
]
let corpusSize = 2000
let corpusStride = 4
let corpusMinimumLength = 3

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 3 || arguments.count == 4, let alphabet = alphabets[arguments[1]] else {
    FileHandle.standardError.write(Data("usage: make-ngrams <frequency-list> <en|pl|ru> <output.tsv> [holdout-corpus.txt]\n".utf8))
    exit(2)
}
let listPath = arguments[0]
let outputPath = arguments[2]
let corpusPath = arguments.count == 4 ? arguments[3] : nil

guard let text = try? String(contentsOfFile: listPath, encoding: .utf8) else {
    FileHandle.standardError.write(Data("cannot read \(listPath)\n".utf8))
    exit(1)
}

struct Entry {
    let word: String
    let frequency: Double
}

var entries: [Entry] = []
for line in text.split(whereSeparator: \.isNewline) {
    let parts = line.split(separator: " ")
    guard parts.count == 2, let frequency = Double(parts[1]) else { continue }
    let word = parts[0].lowercased()
    guard word.allSatisfy({ alphabet.contains($0) }), word.contains(where: { $0 != "'" }) else { continue }
    entries.append(Entry(word: word, frequency: frequency))
}

var held = Set<String>()
var corpus: [String] = []
if corpusPath != nil {
    var eligible = 0
    for entry in entries where entry.word.count >= corpusMinimumLength {
    if corpus.count == corpusSize { break }
        if eligible % corpusStride == 0 {
            corpus.append(entry.word)
            held.insert(entry.word)
        }
        eligible += 1
    }
}

var trigramWeights: [String: Double] = [:]
for entry in entries where !held.contains(entry.word) {
    let weight = log(1 + entry.frequency)
    let characters = Array("^" + entry.word + "$")
    guard characters.count >= 3 else { continue }
    for index in 0...(characters.count - 3) {
        trigramWeights[String(characters[index..<index + 3]), default: 0] += weight
    }
}

var prefixTotals: [String: Double] = [:]
for (trigram, weight) in trigramWeights {
    prefixTotals[String(trigram.prefix(2)), default: 0] += weight
}

var logProbabilities: [String: Double] = [:]
for (trigram, weight) in trigramWeights {
    logProbabilities[trigram] = log(weight / prefixTotals[String(trigram.prefix(2))]!)
}
let unseen = (logProbabilities.values.min() ?? -10) - 1

var lines = ["unseen\t" + String(format: "%.4f", unseen)]
for trigram in logProbabilities.keys.sorted() {
    lines.append(trigram + "\t" + String(format: "%.4f", logProbabilities[trigram]!))
}
do {
    try (lines.joined(separator: "\n") + "\n").write(toFile: outputPath, atomically: true, encoding: .utf8)
    if let corpusPath {
        try (corpus.joined(separator: "\n") + "\n").write(toFile: corpusPath, atomically: true, encoding: .utf8)
    }
} catch {
    FileHandle.standardError.write(Data("cannot write output: \(error.localizedDescription)\n".utf8))
    exit(1)
}
print("\(arguments[1]): \(entries.count) words, \(held.count) held out, \(logProbabilities.count) trigrams, unseen \(unseen)")
