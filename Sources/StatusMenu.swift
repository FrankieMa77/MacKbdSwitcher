import AppKit
import Carbon
import ServiceManagement

final class StatusMenu: NSObject, NSMenuDelegate {
    private let monitor: GlobeMonitor
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(monitor: GlobeMonitor) {
        self.monitor = monitor
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
        if let current = InputSources.current() {
            item.button?.title = InputSources.shortName(current)
        } else {
            item.button?.title = "?"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let currentID = InputSources.current().map { InputSources.id($0) }

        for source in InputSources.cyclable() {
            let entry = NSMenuItem(title: InputSources.name(source), action: #selector(selectSource(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = InputSources.id(source)
            entry.state = InputSources.id(source) == currentID ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())

        if let status = statusItem() {
            menu.addItem(status)
            menu.addItem(.separator())
        }

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MacKbdGlobe", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func statusItem() -> NSMenuItem? {
        if monitor.state == .needsPermission {
            return actionItem(
                "Allow Input Monitoring…",
                #selector(openInputMonitoring)
            )
        }
        if fnUsageType() != 0 {
            return actionItem("Set 🌐 key to “Do Nothing”…", #selector(openKeyboardSettings))
        }
        if monitor.state == .running(fnKeyboards: 0) {
            let entry = NSMenuItem(title: "Globe key not found", action: nil, keyEquivalent: "")
            entry.isEnabled = false
            return entry
        }
        return nil
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
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
        InputSources.select(id: id)
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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
