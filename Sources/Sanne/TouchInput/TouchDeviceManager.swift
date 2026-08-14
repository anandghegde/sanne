import Foundation
import IOKit
import IOKit.hid

/// Single MultitouchSupport enumerator. Fans frames by `DeviceKind`.
final class TouchDeviceManager: @unchecked Sendable {
    static let shared = TouchDeviceManager()

    private let pipeline = DispatchQueue(label: "app.sanne.touch.pipeline")
    private let lock = NSLock()
    private var retainedLists: [CFArray] = []
    private var trackpadDevices: [PrivateMT.DeviceRef] = []
    private var mouseDevices: [PrivateMT.DeviceRef] = []
    private var started = false
    private var listeners: [UUID: (TouchFrame) -> Void] = [:]
    private var totalCallbacks = 0
    private var trackpadKind: DeviceKind = .builtInTrackpad
    private var hidWatcher: HIDDeviceWatcher?

    private static let trackpadCallback: PrivateMT.ContactCallback = { device, touches, num, _, _ in
        TouchDeviceManager.shared.handleTrackpad(device: device, touches: touches, count: Int(num))
        return 0
    }

    private static let mouseCallback: PrivateMT.ContactCallback = { device, touches, num, timestamp, frame in
        TouchDeviceManager.shared.handleMouse(
            device: device,
            touches: touches,
            count: Int(num),
            timestamp: timestamp,
            frame: frame
        )
        return 0
    }

    var pipelineQueue: DispatchQueue { pipeline }

    var magicMouseDeviceCount: Int {
        lock.lock(); defer { lock.unlock() }
        return mouseDevices.count
    }

    private func handleTrackpad(device: Int32, touches: UnsafeMutableRawPointer?, count: Int) {
        lock.lock()
        totalCallbacks += 1
        let n = totalCallbacks
        let kind = trackpadKind
        lock.unlock()
        PerfCounters.incTrackpadCallbacks()

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
                        phase: PrivateMT.isPhysicalContact(t.state) ? .moved : .ended,
                        size: t.size,
                        velX: t.velX,
                        velY: t.velY
                    )
                )
            }
        }

        if LogRing.shared.shouldLogTouchFrame() {
            Log.debug(.mt, "trackpad cb#\(n) dev=\(device) num=\(count) kind=\(kind.rawValue)")
        }

        emit(TouchFrame(
            timestamp: CFAbsoluteTimeGetCurrent(),
            deviceID: Int64(device),
            deviceKind: kind,
            touches: points
        ))
    }

    private func handleMouse(
        device: Int32,
        touches: UnsafeMutableRawPointer?,
        count: Int,
        timestamp: Double,
        frame: Int32
    ) {
        MagicMouseTapController.shared.handleRaw(
            device: device,
            touches: touches,
            numTouches: count,
            timestamp: timestamp,
            frame: frame
        )
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
        if started { return .success(trackpadDevices.count) }

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
                "device[\(i)] kind=\(classified.rawValue) builtIn=\(PrivateMT.deviceIsBuiltIn(d)) " +
                "opaque=\(PrivateMT.deviceIsOpaqueSurface(d)) force=\(PrivateMT.deviceSupportsForce(d))"
            )
            if TouchDeviceClassifier.isTrackpad(classified) {
                if classified == .magicTrackpad { kind = .magicTrackpad }
                trackpadDevices.append(d)
                PrivateMT.register(d, Self.trackpadCallback)
                PrivateMT.start(d)
                Log.info(.touch, "  MONITORING trackpad")
            } else if TouchDeviceClassifier.isMagicMouse(classified) {
                mouseDevices.append(d)
                PrivateMT.register(d, Self.mouseCallback)
                PrivateMT.start(d)
                Log.info(.touch, "  MONITORING Magic Mouse")
            } else {
                Log.info(.touch, "  skip \(classified.rawValue)")
            }
        }
        trackpadKind = kind

        started = true
        Log.info(
            .touch,
            "TouchDeviceManager trackpads=\(trackpadDevices.count) mice=\(mouseDevices.count)"
        )
        return .success(trackpadDevices.count)
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }
        for d in trackpadDevices {
            PrivateMT.unregister(d, Self.trackpadCallback)
            PrivateMT.stop(d)
        }
        for d in mouseDevices {
            PrivateMT.unregister(d, Self.mouseCallback)
            PrivateMT.stop(d)
        }
        trackpadDevices.removeAll()
        mouseDevices.removeAll()
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
        lock.lock()
        let local = "trackpadDev=\(trackpadDevices.count) mouseDev=\(mouseDevices.count) trackpadCb=\(totalCallbacks)"
        lock.unlock()
        // Do not call into MagicMouseTapController while holding `lock` — its stats
        // reads `magicMouseDeviceCount`, which takes this same non-recursive lock.
        return "\(local) \(MagicMouseTapController.shared.stats)"
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

/// IOKit first-match / terminate watcher for HID add/remove. Not used for callback registration.
final class HIDDeviceWatcher {
    private var port: IONotificationPortRef?
    private var added: io_iterator_t = 0
    private var removed: io_iterator_t = 0
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        let notify = IONotificationPortCreate(kIOMainPortDefault)
        port = notify
        let source = IONotificationPortGetRunLoopSource(notify).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let matchingAdd = IOServiceMatching(kIOHIDDeviceKey)
        let matchingRemove = IOServiceMatching(kIOHIDDeviceKey)

        let addedCB: IOServiceMatchingCallback = { refcon, iterator in
            HIDDeviceWatcher.drain(iterator)
            Unmanaged<HIDDeviceWatcher>.fromOpaque(refcon!).takeUnretainedValue().onChange()
        }
        let removedCB: IOServiceMatchingCallback = { refcon, iterator in
            HIDDeviceWatcher.drain(iterator)
            Unmanaged<HIDDeviceWatcher>.fromOpaque(refcon!).takeUnretainedValue().onChange()
        }

        IOServiceAddMatchingNotification(notify, kIOFirstMatchNotification, matchingAdd, addedCB, ctx, &added)
        IOServiceAddMatchingNotification(notify, kIOTerminatedNotification, matchingRemove, removedCB, ctx, &removed)
        HIDDeviceWatcher.drain(added)
        HIDDeviceWatcher.drain(removed)
    }

    func stop() {
        if added != 0 { IOObjectRelease(added); added = 0 }
        if removed != 0 { IOObjectRelease(removed); removed = 0 }
        if let port {
            IONotificationPortDestroy(port)
            self.port = nil
        }
    }

    private static func drain(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }
}
