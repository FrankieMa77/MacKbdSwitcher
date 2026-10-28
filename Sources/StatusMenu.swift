import AppKit
import Carbon
import ServiceManagement

final class StatusMenu: NSObject, NSMenuDelegate {
    private let monitor: GlobeMonitor
    private let stats: KeyStats
    private let switcher: LayoutSwitcher
    private let click: ClickSound
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(monitor: GlobeMonitor, stats: KeyStats, switcher: LayoutSwitcher, click: ClickSound) {
        self.monitor = monitor
        self.stats = stats
        self.switcher = switcher
        self.click = click
        super.init()
    }

    func start() {
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: name,
            object: nil
        )
        refreshTitle()
    }

    @objc private func inputSourceChanged() {
        refreshTitle()
    }

    func refreshTitle() {
        guard let button = item.button else { return }
        var image = Badge.image("?")
        var name = "Keyboard layout"
        if let current = InputSources.current() {
            image = Badge.image(for: current)
            name = InputSources.name(current)
        }
        button.image = image
        button.title = ""
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel(name)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let currentID = InputSources.current().map { InputSources.id($0) }

        menu.addItem(NSMenuItem.sectionHeader(title: "Keyboard Layouts"))
        for source in InputSources.cyclable() {
            let entry = NSMenuItem(title: InputSources.name(source), action: #selector(selectSource(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = InputSources.id(source)
            entry.image = Badge.image(for: source)
            entry.state = InputSources.id(source) == currentID ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())

        menu.addItem(NSMenuItem.sectionHeader(title: "Characters Typed"))
        let statsEntry = NSMenuItem()
        statsEntry.view = StatsView(today: stats.todayCounts, allTime: stats.allTimeCounts)
        menu.addItem(statsEntry)
        menu.addItem(bookItem())
        menu.addItem(actionItem("Reset Statistics…", #selector(resetStats), symbol: "arrow.counterclockwise"))
        menu.addItem(.separator())

        if let status = statusItem() {
            menu.addItem(status)
            menu.addItem(.separator())
        }

        let sound = actionItem("Click Sound", #selector(toggleSound), symbol: "speaker.wave.2")
        sound.state = click.enabled ? .on : .off
        menu.addItem(sound)
        let login = actionItem("Open at Login", #selector(toggleLogin), symbol: "power")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(aboutItem())
        let quit = actionItem("Quit MacKbdGlobe", #selector(quit), symbol: "xmark.rectangle")
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    private func bookItem() -> NSMenuItem {
        let entry = NSMenuItem(title: "Book Progress", action: nil, keyEquivalent: "")
        entry.image = NSImage(systemSymbolName: "books.vertical", accessibilityDescription: nil)
        let panel = NSMenuItem()
        panel.view = BookProgressView(total: stats.allTimeCounts.values.reduce(0, +))
        let submenu = NSMenu()
        submenu.addItem(panel)
        entry.submenu = submenu
        return entry
    }

    @objc private func toggleSound() {
        click.enabled.toggle()
    }

    @objc private func resetStats() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reset typing statistics?"
        alert.informativeText = "Today and all-time counts will be set to zero."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            stats.reset()
        }
    }

    private func statusItem() -> NSMenuItem? {
        if monitor.state == .needsPermission {
            return actionItem(
                "Allow Input Monitoring…",
                #selector(openInputMonitoring),
                symbol: "lock.shield"
            )
        }
        if fnUsageType() != 0 {
            return actionItem("Set 🌐 key to “Do Nothing”…", #selector(openKeyboardSettings), symbol: "globe")
        }
        if monitor.state == .running(fnKeyboards: 0) {
            let entry = NSMenuItem(title: "Globe key not found", action: nil, keyEquivalent: "")
            entry.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            entry.isEnabled = false
            return entry
        }
        return nil
    }

    private func actionItem(_ title: String, _ action: Selector, symbol: String? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        if let symbol {
            entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return entry
    }

    private func fnUsageType() -> Int? {
        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesAppSynchronize(domain)
        guard let value = CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, domain) as? NSNumber else {
            return nil
        }
        return value.intValue
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        switcher.select(id: id)
    }

    @objc private func openInputMonitoring() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    @objc private func openKeyboardSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    private func open(_ address: String) {
        if let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Open at Login failed: %@", error.localizedDescription)
        }
    }

    private func aboutItem() -> NSMenuItem {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let entry = actionItem("About MacKbdGlobe", #selector(about), symbol: "info.circle")
        if #available(macOS 14.4, *) {
            entry.subtitle = "Version \(version)"
        } else {
            entry.title = "About MacKbdGlobe \(version)"
        }
        return entry
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
