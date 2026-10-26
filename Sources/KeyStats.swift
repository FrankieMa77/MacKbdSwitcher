import Foundation

final class KeyStats {
    private let defaults = UserDefaults.standard
    private var today: [String: Int]
    private var todayDate: String
    private var allTime: [String: Int]
    private var dirty = false
    private var timer: Timer?

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init() {
        today = defaults.dictionary(forKey: "stats.today") as? [String: Int] ?? [:]
        todayDate = defaults.string(forKey: "stats.todayDate") ?? ""
        allTime = defaults.dictionary(forKey: "stats.allTime") as? [String: Int] ?? [:]
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.save()
        }
    }

    private func rollover() {
        let date = formatter.string(from: Date())
        if date != todayDate {
            today = [:]
            todayDate = date
            dirty = true
        }
    }

    func record() {
        guard let current = InputSources.current() else { return }
        let label = InputSources.shortName(current)
        rollover()
        today[label, default: 0] += 1
        allTime[label, default: 0] += 1
        dirty = true
    }

    var todayCounts: [String: Int] {
        rollover()
        return today
    }

    var allTimeCounts: [String: Int] {
        allTime
    }

    func reset() {
        today = [:]
        allTime = [:]
        todayDate = formatter.string(from: Date())
        dirty = true
        save()
    }

    func save() {
        guard dirty else { return }
        defaults.set(today, forKey: "stats.today")
        defaults.set(todayDate, forKey: "stats.todayDate")
        defaults.set(allTime, forKey: "stats.allTime")
        dirty = false
    }
}
