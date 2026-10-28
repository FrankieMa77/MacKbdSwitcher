import AppKit

final class StatsView: NSView {
    init(today: [String: Int], allTime: [String: Int]) {
        super.init(frame: .zero)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        func format(_ number: Int) -> String {
            formatter.string(from: NSNumber(value: number)) ?? String(number)
        }
        let size = NSFont.menuFont(ofSize: 0).pointSize
        let content: NSView
        if allTime.values.reduce(0, +) == 0 {
            let label = NSTextField(labelWithString: "No typing yet")
            label.textColor = .secondaryLabelColor
            content = label
        } else {
            func text(_ string: String, _ font: NSFont, _ color: NSColor, trailing: Bool) -> NSTextField {
                let field = NSTextField(labelWithString: string)
                field.font = font
                field.textColor = color
                field.alignment = trailing ? .right : .left
                return field
            }
            let header = NSFont.systemFont(ofSize: 11, weight: .medium)
            var rows: [[NSView]] = [[
                text("", header, .secondaryLabelColor, trailing: false),
                text("Today", header, .secondaryLabelColor, trailing: true),
                text("All time", header, .secondaryLabelColor, trailing: true),
            ]]
            let labels = Set(allTime.keys).union(today.keys).sorted {
                let left = allTime[$0, default: 0]
                let right = allTime[$1, default: 0]
                return left != right ? left > right : $0 < $1
            }
            func row(_ title: String, _ first: Int, _ second: Int, weight: NSFont.Weight) -> [NSView] {
                let label = weight == .regular ? NSFont.menuFont(ofSize: 0) : NSFont.systemFont(ofSize: size, weight: weight)
                let digits = NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
                return [
                    text(title, label, .labelColor, trailing: false),
                    text(format(first), digits, .labelColor, trailing: true),
                    text(format(second), digits, .labelColor, trailing: true),
                ]
            }
            for label in labels {
                rows.append(row(label, today[label, default: 0], allTime[label, default: 0], weight: .regular))
            }
            rows.append(row("Total", today.values.reduce(0, +), allTime.values.reduce(0, +), weight: .semibold))
            let grid = NSGridView(views: rows)
            grid.columnSpacing = 18
            grid.rowSpacing = 3
            for index in 1...2 {
                grid.column(at: index).xPlacement = .trailing
            }
            content = grid
        }
        let fitting = content.fittingSize
        content.frame = NSRect(x: 14, y: 6, width: fitting.width, height: fitting.height)
        addSubview(content)
        frame = NSRect(x: 0, y: 0, width: fitting.width + 28, height: fitting.height + 8)
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
