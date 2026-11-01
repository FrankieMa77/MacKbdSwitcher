import AppKit
import Carbon

struct LanguageOption {
    let info: LanguageInfo
    let enabled: Bool
}

struct LanguageSection {
    let layoutID: String
    let layoutName: String
    let options: [LanguageOption]
}

final class AutoCorrect {
    private let defaults = UserDefaults.standard
    private let switcher: LayoutSwitcher
    private let exceptions: ExceptionList
    private let engine: CorrectionEngine
    private let tap = TypingTap()
    private var models: [String: LanguageModel?] = [:]
    private var keyMaps: [String: KeyMap?] = [:]
    private var profiles: [String: LayoutProfile?] = [:]
    private var participating: [LayoutProfile]?
    private var alternates: [String: [LayoutProfile]] = [:]
    private var overrides: [String: [String]]
    private var frontmostBundleID: String?
    private let excludedApps: Set<String>

    var enabled: Bool {
        get { defaults.bool(forKey: "autocorrect.enabled") }
        set {
            defaults.set(newValue, forKey: "autocorrect.enabled")
            if newValue {
                requestAccessibility()
                tap.start()
            }
            engine.handle(.reset, context: nil)
        }
    }

    var hasAccess: Bool {
        AXIsProcessTrusted()
    }

    var needsAccessibility: Bool {
        enabled && !hasAccess
    }

    var lacksSupportedPair: Bool {
        enabled && !LayoutPairing.hasSupportedPair(among: participatingProfiles())
    }

    var exceptionCount: Int {
        exceptions.count
    }

    private lazy var availableLanguages: Set<String> = Set(
        SupportedLanguages.all.map(\.code).filter { model(for: $0) != nil }
    )

    init(switcher: LayoutSwitcher) {
        self.switcher = switcher
        defaults.register(defaults: [
            "autocorrect.enabled": false,
            "autocorrect.excludedApps": ExcludedApps.defaults,
        ])
        excludedApps = Set(defaults.stringArray(forKey: "autocorrect.excludedApps") ?? ExcludedApps.defaults)
        overrides = defaults.dictionary(forKey: "autocorrect.languages") as? [String: [String]] ?? [:]
        let stored = defaults.stringArray(forKey: "autocorrect.exceptions") ?? []
        exceptions = ExceptionList(words: stored)
        engine = CorrectionEngine(detector: WordDetector(lexicon: SpellLexicon()), exceptions: exceptions)
        exceptions.onChange = { [defaults] words in
            defaults.set(words, forKey: "autocorrect.exceptions")
        }
    }

    func start() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        tap.handler = { [weak self] event in
            self?.handle(event) ?? .passThrough
        }
        tap.isSuppressed = { [weak self] in
            guard let self else { return true }
            return IsSecureEventInputEnabled() || self.isFrontmostExcluded()
        }
        tap.onReplace = { [switcher] layoutID in
            switcher.select(id: layoutID)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(enabledSourcesChanged),
            name: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil
        )
        tap.start()
    }

    func forceConvert() -> Bool {
        guard tap.isRunning, !IsSecureEventInputEnabled(), !isFrontmostExcluded() else { return false }
        guard case .replace(let deleteCount, let text, let layoutID) = engine.handle(.forceConvert, context: context()) else {
            return false
        }
        EventPoster.replace(deleteCount: deleteCount, text: text)
        switcher.select(id: layoutID)
        return true
    }

    func clearExceptions() {
        exceptions.clear()
    }

    func languageSections() -> [LanguageSection] {
        var sections: [LanguageSection] = []
        for source in InputSources.cyclable() {
            let id = InputSources.id(source)
            guard let alphabet = keyMap(for: source)?.alphabet else { continue }
            let allowed = LayoutLanguages.options(for: alphabet, available: availableLanguages)
            guard !allowed.isEmpty else { continue }
            let selected = resolvedLanguages(for: source, alphabet: alphabet)
            let options = allowed.compactMap { code in
                SupportedLanguages.info(for: code).map { LanguageOption(info: $0, enabled: selected.contains(code)) }
            }
            sections.append(LanguageSection(layoutID: id, layoutName: InputSources.name(source), options: options))
        }
        return sections
    }

    func toggleLanguage(_ language: String, layoutID: String) {
        guard let source = InputSources.cyclable().first(where: { InputSources.id($0) == layoutID }),
              let alphabet = keyMap(for: source)?.alphabet else { return }
        let allowed = LayoutLanguages.options(for: alphabet, available: availableLanguages)
        let selected = resolvedLanguages(for: source, alphabet: alphabet)
        overrides[layoutID] = LayoutLanguages.toggled(language, in: selected, allowed: allowed)
        defaults.set(overrides, forKey: "autocorrect.languages")
        invalidateProfiles()
        engine.handle(.reset, context: nil)
    }

    private func handle(_ event: EngineEvent) -> EngineAction {
        switch event {
        case .key, .boundary, .forceConvert:
            return engine.handle(event, context: context())
        default:
            return engine.handle(event, context: nil)
        }
    }

    private func isFrontmostExcluded() -> Bool {
        guard let id = frontmostBundleID else { return false }
        return excludedApps.contains(id)
    }

    private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func frontmostChanged(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        frontmostBundleID = app?.bundleIdentifier
        engine.handle(.reset, context: nil)
    }

    @objc private func inputSourceChanged() {
        alternates = [:]
        if let current = InputSources.current() {
            engine.handle(.layoutChanged(InputSources.id(current)), context: nil)
        }
    }

    @objc private func enabledSourcesChanged() {
        invalidateProfiles()
    }

    private func invalidateProfiles() {
        profiles = [:]
        participating = nil
        alternates = [:]
    }

    private func context() -> EngineContext? {
        guard let source = InputSources.current(), let current = profile(for: source) else { return nil }
        let candidates: [LayoutProfile]
        if let cached = alternates[current.id] {
            candidates = cached
        } else {
            candidates = LayoutPairing.alternates(current: current, among: participatingProfiles(), order: switcher.recentOrder())
            alternates[current.id] = candidates
        }
        guard !candidates.isEmpty else { return nil }
        return EngineContext(current: current, alternates: candidates, enabled: enabled)
    }

    private func participatingProfiles() -> [LayoutProfile] {
        if let participating {
            return participating
        }
        let result = InputSources.cyclable().compactMap { profile(for: $0) }
        participating = result
        return result
    }

    private func keyMap(for source: TISInputSource) -> KeyMap? {
        let id = InputSources.id(source)
        if let cached = keyMaps[id] {
            return cached
        }
        let built = KeyLayoutTranslator.keyMap(for: source)
        keyMaps[id] = built
        return built
    }

    private func resolvedLanguages(for source: TISInputSource, alphabet: Alphabet) -> [String] {
        LayoutLanguages.resolve(
            systemLanguages: InputSources.languages(source),
            alphabet: alphabet,
            available: availableLanguages,
            override: overrides[InputSources.id(source)]
        )
    }

    private func profile(for source: TISInputSource) -> LayoutProfile? {
        let id = InputSources.id(source)
        if let cached = profiles[id] {
            return cached
        }
        var result: LayoutProfile?
        if let keyMap = keyMap(for: source), let alphabet = keyMap.alphabet {
            let loaded = resolvedLanguages(for: source, alphabet: alphabet).compactMap { model(for: $0) }
            if !loaded.isEmpty {
                result = LayoutProfile(id: id, keyMap: keyMap, models: loaded)
            }
        }
        profiles[id] = result
        return result
    }

    private func model(for language: String) -> LanguageModel? {
        if let cached = models[language] {
            return cached
        }
        var loaded: LanguageModel?
        if let url = Bundle.main.url(forResource: "ngrams-\(language)", withExtension: "tsv") {
            loaded = try? LanguageModel(language: language, contentsOf: url)
        }
        models[language] = loaded
        return loaded
    }
}
