import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = GlobeMonitor()
    private var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = StatusMenu(monitor: monitor)
        statusMenu = menu
        monitor.onChange = { [weak menu] in
            menu?.refreshTitle()
        }
        monitor.start()
        menu.start()
    }
}
