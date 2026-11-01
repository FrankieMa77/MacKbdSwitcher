import AppKit
import Carbon
import IOKit.hid

enum GlobeState: Equatable {
    case starting
    case needsPermission
    case running(fnKeyboards: Int)
}

private let fnPage: Int = 0xFF
private let fnUsage: Int = 0x03
private let tapLimit: CFAbsoluteTime = 0.5

private let valueCallback: IOHIDValueCallback = { context, _, _, value in
    guard let context else { return }
    Unmanaged<GlobeMonitor>.fromOpaque(context).takeUnretainedValue().handle(value)
}

private let deviceCallback: IOHIDDeviceCallback = { context, _, _, _ in
    guard let context else { return }
    let monitor = Unmanaged<GlobeMonitor>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.recount()
    }
}

final class GlobeMonitor {
    private(set) var state: GlobeState = .starting
    var onChange: (() -> Void)?
    var onKeystroke: (() -> Void)?
    var onTap: (() -> Void)?
    var onShiftTap: (() -> Void)?
    var onOtherKey: (() -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var retryTimer: Timer?
    private var requestedAccess = false
    private var fnDown = false
    private var chord = false
    private var shiftAtPress = false
    private var pressedAt: CFAbsoluteTime = 0

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let devices: [[String: Int]] = [
            [kIOHIDDeviceUsagePageKey: 0x01, kIOHIDDeviceUsageKey: 0x06],
            [kIOHIDDeviceUsagePageKey: fnPage, kIOHIDDeviceUsageKey: fnUsage],
        ]
        let elements: [[String: Int]] = [
            [kIOHIDElementUsagePageKey: fnPage, kIOHIDElementUsageKey: fnUsage],
            [kIOHIDElementUsagePageKey: 0x07],
            [kIOHIDElementUsagePageKey: 0x0C],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, devices as CFArray)
        IOHIDManagerSetInputValueMatchingMultiple(manager, elements as CFArray)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerRegisterInputValueCallback(manager, valueCallback, context)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceCallback, context)
        attemptOpen()
    }

    private func attemptOpen() {
        if IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess {
            retryTimer?.invalidate()
            retryTimer = nil
            recount()
            return
        }
        if !requestedAccess {
            requestedAccess = true
            CGRequestListenEventAccess()
        }
        update(.needsPermission)
        if retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.attemptOpen()
            }
        }
    }

    func recount() {
        guard retryTimer == nil else { return }
        var count = 0
        if let set = IOHIDManagerCopyDevices(manager) {
            let matching: [String: Int] = [kIOHIDElementUsagePageKey: fnPage, kIOHIDElementUsageKey: fnUsage]
            for case let device as IOHIDDevice in (set as NSSet).allObjects {
                if let found = IOHIDDeviceCopyMatchingElements(device, matching as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement],
                   !found.isEmpty {
                    count += 1
                }
            }
        }
        update(.running(fnKeyboards: count))
    }

    private func update(_ newState: GlobeState) {
        guard newState != state else { return }
        state = newState
        onChange?()
    }

    private func heldModifiers() -> CGEventFlags {
        CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
    }

    private func isCountable(_ usage: Int) -> Bool {
        switch usage {
        case 0x04...0x27, 0x2C, 0x2D...0x38, 0x64, 0x54...0x57, 0x59...0x63:
            return true
        default:
            return false
        }
    }

    fileprivate func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = Int(IOHIDElementGetUsagePage(element))
        let usage = Int(IOHIDElementGetUsage(element))
        let pressed = IOHIDValueGetIntegerValue(value) != 0

        if page == 0x07 && pressed && isCountable(usage) && !fnDown && !IsSecureEventInputEnabled() {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if !flags.contains(.maskCommand) && !flags.contains(.maskControl) {
                onKeystroke?()
            }
        }

        if page == 0x07 && pressed && (0x04...0xE7).contains(usage) {
            onOtherKey?()
        }

        if page == fnPage && usage == fnUsage {
            if pressed {
                fnDown = true
                pressedAt = CFAbsoluteTimeGetCurrent()
                let held = heldModifiers()
                shiftAtPress = held == .maskShift
                chord = !held.isEmpty && !shiftAtPress
            } else {
                let quick = CFAbsoluteTimeGetCurrent() - pressedAt < tapLimit
                if fnDown && !chord && quick {
                    let held = heldModifiers()
                    if shiftAtPress && held == .maskShift {
                        onShiftTap?()
                    } else if !shiftAtPress && held.isEmpty {
                        onTap?()
                    }
                }
                fnDown = false
                chord = false
                shiftAtPress = false
            }
            return
        }

        guard fnDown, pressed else { return }
        if page == 0x07 {
            if (0x04...0xE7).contains(usage) {
                chord = true
            }
        } else {
            chord = true
        }
    }
}
