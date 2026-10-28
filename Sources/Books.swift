import AppKit

enum Books {
    static let all: [(title: String, author: String, characters: Int)] = [
        ("The Hobbit", "Tolkien", 553_000),
        ("Moby-Dick", "Melville", 1_195_000),
        ("Crime and Punishment", "Dostoevsky", 1_227_000),
        ("Anna Karenina", "Tolstoy", 2_028_000),
        ("Don Quixote", "Cervantes", 2_320_000),
        ("The Count of Monte Cristo", "Dumas", 2_693_000),
        ("The Lord of the Rings", "Tolkien", 2_790_000),
        ("Les Misérables", "Hugo", 3_166_000),
        ("War and Peace", "Tolstoy", 3_406_000),
        ("Harry Potter (all 7 books)", "Rowling", 6_288_000),
    ]
}

private final class BarView: NSView {
    private let ratio: Double

    init(ratio: Double) {
        self.ratio = ratio
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: 6))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 120).isActive = true
        heightAnchor.constraint(equalToConstant: 6).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
        guard ratio > 0 else { return }
        var fill = bounds
        fill.size.width = bounds.width * min(1, ratio)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: fill, xRadius: 3, yRadius: 3).fill()
    }
}

final class BookProgressView: NSView {
    init(total: Int) {
        super.init(frame: .zero)
        let decimal = NumberFormatter()
        decimal.numberStyle = .decimal
        let size = NSFont.menuFont(ofSize: 0).pointSize
        let menuFont = NSFont.menuFont(ofSize: 0)

        let header = NSTextField(labelWithString: "\(decimal.string(from: NSNumber(value: total)) ?? String(total)) characters typed")
        header.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        header.textColor = .secondaryLabelColor

        var rows: [[NSView]] = []
        for book in Books.all {
            let ratio = Double(total) / Double(book.characters)
            let title = NSMutableAttributedString(
                string: book.title,
                attributes: [.font: menuFont, .foregroundColor: NSColor.labelColor]
            )
            title.append(NSAttributedString(
                string: " · \(book.author)",
                attributes: [.font: menuFont, .foregroundColor: NSColor.secondaryLabelColor]
            ))
            let label = NSTextField(labelWithAttributedString: title)
            let percent = NumberFormatter()
            percent.numberStyle = .percent
            percent.minimumFractionDigits = ratio < 0.1 ? 1 : 0
            percent.maximumFractionDigits = ratio < 0.1 ? 1 : 0
            let value = NSTextField(labelWithString: percent.string(from: NSNumber(value: ratio)) ?? "")
            value.font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: ratio >= 1 ? .semibold : .regular)
            value.textColor = .labelColor
            value.alignment = .right
            rows.append([label, BarView(ratio: ratio), value])
        }
        let grid = NSGridView(views: rows)
        grid.columnSpacing = 14
        grid.rowSpacing = 6
        grid.column(at: 2).xPlacement = .trailing
        for index in 0..<grid.numberOfRows {
            grid.row(at: index).yPlacement = .center
        }

        let gridSize = grid.fittingSize
        let headerSize = header.fittingSize
        let width = max(gridSize.width, headerSize.width)
        grid.frame = NSRect(x: 14, y: 6, width: gridSize.width, height: gridSize.height)
        header.frame = NSRect(x: 14, y: 6 + gridSize.height + 6, width: headerSize.width, height: headerSize.height)
        addSubview(grid)
        addSubview(header)
        frame = NSRect(x: 0, y: 0, width: width + 28, height: gridSize.height + headerSize.height + 18)
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
