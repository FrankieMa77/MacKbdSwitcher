import Foundation

public struct EngineContext {
    public let current: LayoutProfile
    public let alternates: [LayoutProfile]
    public let enabled: Bool

    public init(current: LayoutProfile, alternates: [LayoutProfile], enabled: Bool) {
        self.current = current
        self.alternates = alternates
        self.enabled = enabled
    }

    public init(current: LayoutProfile, alternate: LayoutProfile, enabled: Bool) {
        self.init(current: current, alternates: [alternate], enabled: enabled)
    }
}

public enum EngineEvent {
    case key(KeyStroke)
    case backspace
    case boundary(String)
    case reset
    case forceConvert
    case layoutChanged(String)
}

public enum EngineAction: Equatable {
    case passThrough
    case replace(deleteCount: Int, text: String, switchTo: String)
}

public final class CorrectionEngine {
    public static let maximumWordLength = 48
    public static let rememberedBoundary = " "

    private struct Replacement {
        let originalLayoutID: String
        let originalText: String
        let deleteCount: Int
        let exceptionKey: String?
    }

    private struct Completed {
        let strokes: [KeyStroke]
        let boundary: String
        let layoutID: String
        let replacement: Replacement?
    }

    private let detector: WordDetector
    private let exceptions: ExceptionStore
    private var buffer: [KeyStroke] = []
    private var bufferLayoutID: String?
    private var overflowed = false
    private var completed: Completed?
    private var expectedLayoutID: String?

    public init(detector: WordDetector, exceptions: ExceptionStore) {
        self.detector = detector
        self.exceptions = exceptions
    }

    public var pendingWordLength: Int {
        buffer.count
    }

    @discardableResult
    public func handle(_ event: EngineEvent, context: EngineContext?) -> EngineAction {
        switch event {
        case .key(let stroke):
            return key(stroke, context: context)
        case .backspace:
            return backspace()
        case .boundary(let text):
            return boundary(text, context: context)
        case .reset:
            resetAll()
            return .passThrough
        case .forceConvert:
            return forceConvert(context: context)
        case .layoutChanged(let id):
            if id == expectedLayoutID {
                expectedLayoutID = nil
            } else {
                resetAll()
            }
            return .passThrough
        }
    }

    private func resetAll() {
        buffer = []
        bufferLayoutID = nil
        overflowed = false
        completed = nil
        expectedLayoutID = nil
    }

    private func key(_ stroke: KeyStroke, context: EngineContext?) -> EngineAction {
        completed = nil
        guard !overflowed else { return .passThrough }
        guard let context, !context.alternates.isEmpty else {
            buffer = []
            bufferLayoutID = nil
            return .passThrough
        }
        if stroke.option, !(context.current.keyMap.character(for: stroke)?.first?.isLetter ?? false) {
            buffer = []
            bufferLayoutID = nil
            return .passThrough
        }
        if let id = bufferLayoutID, id != context.current.id {
            buffer = []
        }
        if buffer.count >= CorrectionEngine.maximumWordLength {
            buffer = []
            bufferLayoutID = nil
            overflowed = true
            return .passThrough
        }
        buffer.append(stroke)
        bufferLayoutID = context.current.id
        return .passThrough
    }

    private func backspace() -> EngineAction {
        if let completed, let replacement = completed.replacement {
            return undo(completed, replacement)
        }
        completed = nil
        if !buffer.isEmpty {
            buffer.removeLast()
        }
        return .passThrough
    }

    private func undo(_ word: Completed, _ replacement: Replacement) -> EngineAction {
        if let key = replacement.exceptionKey {
            exceptions.add(key)
        }
        completed = Completed(strokes: word.strokes, boundary: word.boundary, layoutID: replacement.originalLayoutID, replacement: nil)
        expectedLayoutID = replacement.originalLayoutID
        return .replace(
            deleteCount: replacement.deleteCount,
            text: replacement.originalText + word.boundary,
            switchTo: replacement.originalLayoutID
        )
    }

    private func boundary(_ text: String, context: EngineContext?) -> EngineAction {
        completed = nil
        if overflowed {
            overflowed = false
            buffer = []
            bufferLayoutID = nil
            return .passThrough
        }
        guard !buffer.isEmpty else { return .passThrough }
        let strokes = buffer
        let layoutID = bufferLayoutID
        buffer = []
        bufferLayoutID = nil
        guard let context, !context.alternates.isEmpty, context.current.id == layoutID else { return .passThrough }
        let remembered = text == CorrectionEngine.rememberedBoundary
        if context.enabled {
            let verdict = detector.evaluate(
                strokes: strokes,
                current: context.current,
                alternates: context.alternates,
                exceptions: exceptions
            )
            if case .convert(let converted) = verdict.decision, let targetID = verdict.alternateID {
                if remembered {
                    let replacement = Replacement(
                        originalLayoutID: context.current.id,
                        originalText: context.current.keyMap.text(for: strokes) ?? "",
                        deleteCount: converted.count + text.count,
                        exceptionKey: verdict.exceptionKey
                    )
                    completed = Completed(strokes: strokes, boundary: text, layoutID: context.current.id, replacement: replacement)
                }
                expectedLayoutID = targetID
                return .replace(deleteCount: strokes.count, text: converted + text, switchTo: targetID)
            }
        }
        if remembered {
            completed = Completed(strokes: strokes, boundary: text, layoutID: context.current.id, replacement: nil)
        }
        return .passThrough
    }

    private func forceConvert(context: EngineContext?) -> EngineAction {
        guard let context, !context.alternates.isEmpty else { return .passThrough }
        if !buffer.isEmpty, bufferLayoutID == context.current.id {
            let strokes = buffer
            buffer = []
            bufferLayoutID = nil
            completed = nil
            guard let forced = detector.convert(strokes: strokes, current: context.current, alternates: context.alternates) else {
                return .passThrough
            }
            expectedLayoutID = forced.alternateID
            return .replace(deleteCount: strokes.count, text: forced.text, switchTo: forced.alternateID)
        }
        guard let word = completed else { return .passThrough }
        if let replacement = word.replacement {
            return undo(word, replacement)
        }
        completed = nil
        guard word.layoutID == context.current.id,
              let forced = detector.convert(strokes: word.strokes, current: context.current, alternates: context.alternates)
        else {
            return .passThrough
        }
        expectedLayoutID = forced.alternateID
        return .replace(
            deleteCount: word.strokes.count + word.boundary.count,
            text: forced.text + word.boundary,
            switchTo: forced.alternateID
        )
    }
}
