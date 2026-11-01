import Foundation

public struct LayoutProfile: Sendable {
    public let id: String
    public let keyMap: KeyMap
    public let models: [LanguageModel]
    public let alphabet: Alphabet?

    public init(id: String, keyMap: KeyMap, models: [LanguageModel]) {
        self.id = id
        self.keyMap = keyMap
        self.models = models
        self.alphabet = keyMap.alphabet
    }

    public init(id: String, keyMap: KeyMap, model: LanguageModel) {
        self.init(id: id, keyMap: keyMap, models: [model])
    }

    public var languages: [String] {
        models.map(\.language)
    }

    public var language: String {
        models.first?.language ?? ""
    }

    public func score(_ text: String) -> Double {
        models.map { $0.score(text) }.max() ?? LanguageModel.defaultUnseen
    }
}

public enum LayoutPairing {
    public static func alternates(current: LayoutProfile, among profiles: [LayoutProfile], order: [String]) -> [LayoutProfile] {
        guard let alphabet = current.alphabet else { return [] }
        let candidates = profiles.filter { $0.id != current.id && $0.alphabet != nil && $0.alphabet != alphabet && !$0.models.isEmpty }
        func rank(_ profile: LayoutProfile) -> Int {
            order.firstIndex(of: profile.id) ?? order.count
        }
        return candidates.enumerated()
            .sorted { rank($0.element) != rank($1.element) ? rank($0.element) < rank($1.element) : $0.offset < $1.offset }
            .map(\.element)
    }

    public static func hasSupportedPair(among profiles: [LayoutProfile]) -> Bool {
        let usable = profiles.filter { $0.alphabet != nil && !$0.models.isEmpty }
        return Set(usable.compactMap(\.alphabet)).count >= 2
    }
}
