import Carbon
import Foundation

final class LayoutSwitcher {
    private let defaults = UserDefaults.standard
    private let click: ClickSound
    private var recent: [String]
    private var snapshot: [String] = []
    private var step = 0
    private var lastTap: CFAbsoluteTime = 0
    private var inBurst = false

    init(click: ClickSound) {
        self.click = click
        recent = defaults.stringArray(forKey: "switch.recent") ?? []
    }

    func start() {
        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: name,
            object: nil
        )
    }

    @objc private func inputSourceChanged() {
        guard let current = currentID(), current != recent.first else { return }
        promote(current)
    }

    private func currentID() -> String? {
        InputSources.current().map { InputSources.id($0) }
    }

    private func promote(_ id: String) {
        recent = [id] + recent.filter { $0 != id }
        defaults.set(recent, forKey: "switch.recent")
    }

    private func ordered() -> [String] {
        let enabled = InputSources.cyclable().map { InputSources.id($0) }
        var result = recent.filter { enabled.contains($0) }
        result += enabled.filter { !result.contains($0) }
        if let current = currentID(), let index = result.firstIndex(of: current) {
            result.remove(at: index)
            result.insert(current, at: 0)
        }
        return result
    }

    func recentOrder() -> [String] {
        ordered()
    }

    func tap() {
        let now = CFAbsoluteTimeGetCurrent()
        if inBurst && now - lastTap < 0.4 {
            step += 1
        } else {
            snapshot = ordered()
            let known = currentID().map { snapshot.contains($0) } ?? false
            step = known ? 1 : 0
        }
        guard snapshot.count >= 2 else { return }
        let target = snapshot[step % snapshot.count]
        InputSources.select(id: target)
        click.play()
        recent = [target] + snapshot.filter { $0 != target }
        defaults.set(recent, forKey: "switch.recent")
        lastTap = now
        inBurst = true
    }

    func interrupt() {
        inBurst = false
    }

    func select(id: String) {
        InputSources.select(id: id)
        click.play()
        promote(id)
        inBurst = false
    }
}
