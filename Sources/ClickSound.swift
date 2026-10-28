import AppKit

final class ClickSound {
    private let defaults = UserDefaults.standard
    private let sound: NSSound?

    var enabled: Bool {
        get { defaults.bool(forKey: "sound.click") }
        set { defaults.set(newValue, forKey: "sound.click") }
    }

    init() {
        defaults.register(defaults: ["sound.click": true])
        let rate = 44_100
        let count = rate * 12 / 1000
        var data = Data()
        func append32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append32(UInt32(36 + count * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append32(16)
        append16(1)
        append16(1)
        append32(UInt32(rate))
        append32(UInt32(rate * 2))
        append16(2)
        append16(16)
        data.append(contentsOf: Array("data".utf8))
        append32(UInt32(count * 2))
        for index in 0..<count {
            let t = Double(index) / Double(rate)
            let value = 0.5 * sin(2 * Double.pi * 2200 * t) * exp(-t / 0.0018)
            append16(UInt16(bitPattern: Int16(value * 32767)))
        }
        sound = NSSound(data: data)
        sound?.volume = 0.3
    }

    func play() {
        guard enabled, let sound else { return }
        sound.stop()
        sound.play()
    }
}
