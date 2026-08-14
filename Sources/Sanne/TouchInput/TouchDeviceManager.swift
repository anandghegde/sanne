import Foundation
import IOKit
import IOKit.hid

/// Trackpad multitouch for titlebar gestures. Magic Mouse uses MagicMouseTapController.
final class TouchDeviceManager: @unchecked Sendable {
    static let shared = TouchDeviceManager()

    private let pipeline = DispatchQueue(label: "app.sanne.touch.pipeline")
    private let lock = NSLock()
    private var retainedLists: [CFArray] = []
    private var devices: [PrivateMT.DeviceRef] = []
    private var started = false
    private var listeners: [UUID: (TouchFrame) -> Void] = [:]
    private var totalCallbacks = 0
    private var trackpadKind: DeviceKind = .builtInTrackpad

    private static let callback: PrivateMT.ContactCallback = { device, touches, num, _, _ in
        TouchDeviceManager.shared.handle(device: device, touches: touches, count: Int(num))
        return 0
    }

    private func handle(device: Int32, touches: UnsafeMutableRawPointer?, count: Int) {
        lock.lock()
        totalCallbacks += 1
        let n = totalCallbacks
        lock.unlock()

        var points: [TouchPoint] = []
        if let touches, count > 0 {
            for i in 0..<count {
                let t = PrivateMT.touch(at: touches, index: i)
                points.append(
                    TouchPoint(
                        id: Int(t.identifier),
                        normalized: CGPoint(x: CGFloat(t.normX), y: CGFloat(t.normY)),
                        majorAxis: t.majorAxis,
                        minorAxis: t.minorAxis,
                        state: Int(t.state),
                        // Proximity/hover states (1/2/6/7) are not physical contact —
                        // report them as ended so recognizers never see hovering fingers.
                        phase: PrivateMT.isPhysicalContact(t.state) ? .moved : .ended
                    )
                )
            }
        }

        lock.lock()
        let kind = trackpadKind
        lock.unlock()

        if n <= 15 {
            Log.debug(.mt, "trackpad cb#\(n) dev=\(device) num=\(count) kind=\(kind.rawValue)")
        }

        emit(TouchFrame(
            timestamp: Date(),
            deviceID: Int64(device),
            deviceKind: kind,
            touches: points
        ))
    }

    @discardableResult
    func addListener(_ block: @escaping (TouchFrame) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        listeners[id] = block
        lock.unlock()
        return id
    }

    func removeListener(_ id: UUID) {
        lock.lock()
        listeners[id] = nil
        lock.unlock()
    }

    private func emit(_ frame: TouchFrame) {
        lock.lock()
        let copy = Array(listeners.values)
        lock.unlock()
        pipeline.async { for l in copy { l(frame) } }
    }

    func start() -> Result<Int, Error> {
        lock.lock()
        defer { lock.unlock() }
        if started { return .success(devices.count) }

        guard PrivateMT.load() else {
            return .failure(TouchError.loadFailed(PrivateMT.loadError ?? "unknown"))
        }
        guard let list = PrivateMT.createDeviceList() else {
            return .failure(TouchError.noDevices)
        }
        retainedLists.append(list.array)

        var kind: DeviceKind = .builtInTrackpad
        for (i, d) in list.devices.enumerated() {
            let classified = PrivateMT.classify(d)
            Log.info(
                .touch,
                "trackpad-path[\(i)] kind=\(classified.rawValue) builtIn=\(PrivateMT.deviceIsBuiltIn(d)) " +
                "opaque=\(PrivateMT.deviceIsOpaqueSurface(d)) force=\(PrivateMT.deviceSupportsForce(d))"
            )
            // Only trackpads. Registering a Magic Mouse here would replace its tap callback.
            guard TouchDeviceClassifier.isTrackpad(classified) else {
                Log.info(.touch, "  skip \(classified.rawValue) (owned by MagicMouseTapController)")
                continue
            }
            if classified == .magicTrackpad { kind = .magicTrackpad }
            devices.append(d)
            PrivateMT.register(d, Self.callback)
            PrivateMT.start(d)
        }
        trackpadKind = kind

        started = true
        Log.info(.touch, "TouchDeviceManager devices=\(devices.count)")
        return .success(devices.count)
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }
        for d in devices {
            PrivateMT.unregister(d, Self.callback)
            PrivateMT.stop(d)
        }
        devices.removeAll()
        retainedLists.removeAll()
        started = false
    }

    func restart() -> Result<Int, Error> {
        stop()
        Thread.sleep(forTimeInterval: 0.15)
        return start()
    }

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return started
    }

    var stats: String {
        lock.lock(); defer { lock.unlock() }
        return "trackpadDev=\(devices.count) trackpadCb=\(totalCallbacks) \(MagicMouseTapController.shared.stats)"
    }

    enum TouchError: LocalizedError {
        case loadFailed(String)
        case noDevices
        var errorDescription: String? {
            switch self {
            case .loadFailed(let s): return s
            case .noDevices: return "No multitouch devices"
            }
        }
    }
}

enum IOKitHints {
    struct Pointer: Equatable {
        var product: String
        var isTrackpad: Bool
        var isMouse: Bool
    }

    static func applePointers() -> [Pointer] {
        var result: [Pointer] = []
        let matching = IOServiceMatching(kIOHIDDeviceKey) as NSMutableDictionary
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return result
        }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            guard let product = propString(service, kIOHIDProductKey as String) else { continue }
            let vendor = propInt(service, kIOHIDVendorIDKey as String) ?? 0
            let lower = product.lowercased()
            guard vendor == 0x05AC || lower.contains("apple") || lower.contains("magic") else { continue }
            let trackpad = lower.contains("trackpad")
            let mouse = lower.contains("mouse")
            if trackpad || mouse {
                result.append(Pointer(product: product, isTrackpad: trackpad, isMouse: mouse))
            }
        }
        return result
    }

    private static func propString(_ s: io_registry_entry_t, _ key: String) -> String? {
        guard let p = IORegistryEntryCreateCFProperty(s, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        return p as? String
    }

    private static func propInt(_ s: io_registry_entry_t, _ key: String) -> Int? {
        guard let p = IORegistryEntryCreateCFProperty(s, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        return (p as? NSNumber)?.intValue
    }
}
