import Foundation

public protocol ExceptionStore: AnyObject {
    func contains(_ word: String) -> Bool
    func add(_ word: String)
}

public final class ExceptionList: ExceptionStore {
    public static let defaultLimit = 1000

    public private(set) var words: [String]
    public let limit: Int
    public var onChange: (([String]) -> Void)?
    private var members: Set<String>

    public init(words: [String] = [], limit: Int = ExceptionList.defaultLimit) {
        self.limit = limit
        self.words = Array(words.suffix(limit))
        self.members = Set(self.words)
    }

    public var count: Int {
        words.count
    }

    public func contains(_ word: String) -> Bool {
        members.contains(word)
    }

    public func add(_ word: String) {
        guard !word.isEmpty, !members.contains(word) else { return }
        words.append(word)
        members.insert(word)
        while words.count > limit {
            members.remove(words.removeFirst())
        }
        onChange?(words)
    }

    public func clear() {
        guard !words.isEmpty else { return }
        words = []
        members = []
        onChange?(words)
    }
}
