import Foundation

public enum TextChunks {
    public static func split(_ text: String, limit: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        var currentLength = 0
        for character in text {
            let length = String(character).utf16.count
            if currentLength + length > limit, !current.isEmpty {
                chunks.append(current)
                current = ""
                currentLength = 0
            }
            current.append(character)
            currentLength += length
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }
}
