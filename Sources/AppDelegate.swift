import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = GlobeMonitor()
    private let stats = KeyStats()
    private let click = ClickSound()
    private lazy var switcher = LayoutSwitcher(click: click)
    private lazy var autoCorrect = AutoCorrect(switcher: switcher)
    private var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = StatusMenu(monitor: monitor, stats: stats, switcher: switcher, click: click, autoCorrect: autoCorrect)
        statusMenu = menu
        monitor.onChange = { [weak menu] in
            menu?.refreshTitle()
        }
        monitor.onKeystroke = { [stats] in
            stats.record()
        }
        monitor.onTap = { [switcher] in
            switcher.tap()
        }
        monitor.onShiftTap = { [switcher, autoCorrect] in
            if !autoCorrect.forceConvert() {
                switcher.tap()
            }
        }
        monitor.onOtherKey = { [switcher] in
            switcher.interrupt()
        }
        stats.start()
        switcher.start()
        autoCorrect.start()
        monitor.start()
        menu.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stats.save()
    }
}
