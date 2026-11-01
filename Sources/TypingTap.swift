import ApplicationServices
import AppKit

private let tapCallback: CGEventTapCallBack = { _, type, event, context in
    guard let context else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<TypingTap>.fromOpaque(context).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}

final class TypingTap {
    var handler: ((EngineEvent) -> EngineAction)?
    var isSuppressed: (() -> Bool)?
    var onReplace: ((String) -> Void)?

    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var retryTimer: Timer?

    var isRunning: Bool {
        port != nil
    }

    func start() {
        guard port == nil else { return }
        if AXIsProcessTrusted(), install() {
            retryTimer?.invalidate()
            retryTimer = nil
            return
        }
        if retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.start()
            }
        }
    }

    private func install() -> Bool {
        let mask: CGEventMask = [
            CGEventType.keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
        ].reduce(0) { $0 | (1 << $1.rawValue) }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: context
        ) else {
            return false
        }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        port = created
        source = runLoopSource
        return true
    }

    private func uninstall() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port {
            CFMachPortInvalidate(port)
        }
        port = nil
        source = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passed = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            _ = handler?(.reset)
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
                if !CGEvent.tapIsEnabled(tap: port) {
                    uninstall()
                    start()
                }
            }
            return passed
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            _ = handler?(.reset)
            return passed
        case .keyDown:
            return handleKey(event)
        default:
            return passed
        }
    }

    private func handleKey(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let passed = Unmanaged.passUnretained(event)
        if event.getIntegerValueField(.eventSourceUserData) == EventPoster.marker {
            return passed
        }
        guard let handler else { return passed }
        let flags = event.flags
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let hasCommandModifier = !flags.intersection([.maskCommand, .maskControl]).isEmpty
        let option = flags.contains(.maskAlternate)
        if isSuppressed?() == true || isRepeat || hasCommandModifier {
            _ = handler(.reset)
            return passed
        }
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let engineEvent: EngineEvent
        switch KeyKind.classify(keyCode: keyCode) {
        case .character:
            engineEvent = .key(KeyStroke(
                keyCode: keyCode,
                shift: flags.contains(.maskShift),
                capsLock: flags.contains(.maskAlphaShift),
                option: option
            ))
        case .boundary(let text):
            engineEvent = option ? .reset : .boundary(text)
        case .backspace:
            engineEvent = option ? .reset : .backspace
        case .reset:
            engineEvent = .reset
        }
        switch handler(engineEvent) {
        case .passThrough:
            return passed
        case .replace(let deleteCount, let text, let layoutID):
            EventPoster.replace(deleteCount: deleteCount, text: text)
            onReplace?(layoutID)
            return nil
        }
    }
}
