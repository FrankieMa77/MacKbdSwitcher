import Carbon

enum InputSources {
    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }

    private static func flag(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue())
    }

    static func cyclable() -> [TISInputSource] {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        let keyboardCategory = kTISCategoryKeyboardInputSource as String
        return list.filter { source in
            string(source, kTISPropertyInputSourceCategory) == keyboardCategory
                && flag(source, kTISPropertyInputSourceIsSelectCapable)
                && flag(source, kTISPropertyInputSourceIsEnabled)
        }
    }

    static func id(_ source: TISInputSource) -> String {
        string(source, kTISPropertyInputSourceID) ?? ""
    }

    static func name(_ source: TISInputSource) -> String {
        string(source, kTISPropertyLocalizedName) ?? ""
    }

    static func shortName(_ source: TISInputSource) -> String {
        if let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
            let languages = Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as? [String]
            if let first = languages?.first, !first.isEmpty {
                return String(first.uppercased().prefix(2))
            }
        }
        return String(name(source).uppercased().prefix(2))
    }

    static func current() -> TISInputSource? {
        TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }

    static func selectNext() {
        let sources = cyclable()
        guard sources.count >= 2 else { return }
        var target = 0
        if let current = current() {
            let currentID = id(current)
            if let index = sources.firstIndex(where: { id($0) == currentID }) {
                target = (index + 1) % sources.count
            }
        }
        TISSelectInputSource(sources[target])
    }

    static func select(id wanted: String) {
        if let source = cyclable().first(where: { id($0) == wanted }) {
            TISSelectInputSource(source)
        }
    }
}
