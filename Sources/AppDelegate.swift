import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = GlobeMonitor()
    private let stats = KeyStats()
    private var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = StatusMenu(monitor: monitor, stats: stats)
        statusMenu = menu
        monitor.onChange = { [weak menu] in
            menu?.refreshTitle()
        }
        monitor.onKeystroke = { [stats] in
            stats.record()
        }
        stats.start()
        monitor.start()
        menu.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stats.save()
    }
}
