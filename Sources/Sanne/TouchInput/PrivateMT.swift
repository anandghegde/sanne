import Foundation
import Darwin

// MARK: - Flat C-compatible touch record (file scope for @convention(c))

/// Matches MultitouchBridge.h / MouseToucher layout (primitives only).
struct MTTouchC {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var foo3: Int32
    var foo4: Int32
    var normX: Float
    var normY: Float
    var velX: Float
    var velY: Float
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absX: Float
    var absY: Float
    var absVelX: Float
    var absVelY: Float
    var zero2_0: Int32
    var zero2_1: Int32
    var unk2: Float
}

/// MultitouchSupport via dlopen. Callback ABI matches MouseToucher:
/// `int (*)(int device, MTTouch *touches, int numTouches, double timestamp, int frame)`
enum PrivateMT {
    private static let path =
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"

    typealias DeviceRef = UnsafeMutableRawPointer

    typealias ContactCallback = @convention(c) (
        Int32,
        UnsafeMutableRawPointer?,
        Int32,
        Double,
        Int32
    ) -> Int32

    private static var handle: UnsafeMutableRawPointer?
    private static var createList: (@convention(c) () -> UnsafeMutableRawPointer?)?
    private static var registerCallback: (@convention(c) (UnsafeMutableRawPointer?, ContactCallback?) -> Void)?
    private static var unregisterCallback: (@convention(c) (UnsafeMutableRawPointer?, ContactCallback?) -> Void)?
    private static var deviceStart: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> Void)?
    private static var deviceStop: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    private static var isBuiltInFn: (@convention(c) (UnsafeMutableRawPointer?) -> Bool)?
    private static var isOpaqueFn: (@convention(c) (UnsafeMutableRawPointer?) -> Bool)?
    private static var supportsForceFn: (@convention(c) (UnsafeMutableRawPointer?) -> Bool)?

    private(set) static var isLoaded = false
    private(set) static var loadError: String?

    @discardableResult
    static func load() -> Bool {
        if isLoaded { return true }
        Log.info(.mt, "dlopen \(path)")
        guard let h = dlopen(path, RTLD_NOW) else {
            loadError = String(cString: dlerror())
            Log.error(.mt, "dlopen FAILED: \(loadError!)")
            return false
        }
        handle = h

        typealias CreateFn = @convention(c) () -> UnsafeMutableRawPointer?
        typealias RegFn = @convention(c) (UnsafeMutableRawPointer?, ContactCallback?) -> Void
        typealias StartFn = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Void
        typealias StopFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
        typealias BoolFn = @convention(c) (UnsafeMutableRawPointer?) -> Bool

        createList = loadSym(h, "MTDeviceCreateList") as CreateFn?
        registerCallback = loadSym(h, "MTRegisterContactFrameCallback") as RegFn?
        unregisterCallback = loadSym(h, "MTUnregisterContactFrameCallback") as RegFn?
        deviceStart = loadSym(h, "MTDeviceStart") as StartFn?
        deviceStop = loadSym(h, "MTDeviceStop") as StopFn?
        isBuiltInFn = loadSym(h, "MTDeviceIsBuiltIn") as BoolFn?
        isOpaqueFn = loadSym(h, "MTDeviceIsOpaqueSurface") as BoolFn?
        supportsForceFn = loadSym(h, "MTDeviceSupportsForce") as BoolFn?

        Log.info(.mt, "MTTouchC size=\(MemoryLayout<MTTouchC>.size) stride=\(MemoryLayout<MTTouchC>.stride)")
        Log.info(.mt, "CreateList=\(createList != nil) Register=\(registerCallback != nil) Start=\(deviceStart != nil)")
        Log.info(.mt, "IsBuiltIn=\(isBuiltInFn != nil) IsOpaque=\(isOpaqueFn != nil) SupportsForce=\(supportsForceFn != nil)")

        guard createList != nil, registerCallback != nil, deviceStart != nil, deviceStop != nil else {
            loadError = "Missing MultitouchSupport symbols"
            Log.error(.mt, loadError!)
            return false
        }
        isLoaded = true
        return true
    }

    private static func loadSym<T>(_ h: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let p = dlsym(h, name) else {
            Log.warn(.mt, "symbol missing: \(name)")
            return nil
        }
        return unsafeBitCast(p, to: T.self)
    }

    /// Retains CFArray — keep the returned array alive while using devices.
    static func createDeviceList() -> (array: CFArray, devices: [DeviceRef])? {
        guard isLoaded, let createList, let raw = createList() else {
            Log.error(.mt, "MTDeviceCreateList failed")
            return nil
        }
        let array = Unmanaged<CFArray>.fromOpaque(raw).takeRetainedValue()
        let count = CFArrayGetCount(array)
        Log.info(.mt, "MTDeviceCreateList count=\(count)")
        var devices: [DeviceRef] = []
        for i in 0..<count {
            guard let v = CFArrayGetValueAtIndex(array, i) else { continue }
            devices.append(UnsafeMutableRawPointer(mutating: v))
        }
        return (array, devices)
    }

    static func start(_ d: DeviceRef) { deviceStart?(d, 0) }
    static func stop(_ d: DeviceRef) { deviceStop?(d) }
    static func register(_ d: DeviceRef, _ cb: ContactCallback?) { registerCallback?(d, cb) }
    static func unregister(_ d: DeviceRef, _ cb: ContactCallback?) { unregisterCallback?(d, cb) }

    static func deviceIsBuiltIn(_ d: DeviceRef) -> Bool { isBuiltInFn?(d) ?? false }
    static func deviceIsOpaqueSurface(_ d: DeviceRef) -> Bool { isOpaqueFn?(d) ?? false }
    /// Force Touch trackpads return true; Magic Mouse returns false.
    static func deviceSupportsForce(_ d: DeviceRef) -> Bool { supportsForceFn?(d) ?? false }

    static func classify(_ d: DeviceRef) -> DeviceKind {
        TouchDeviceClassifier.classify(
            .init(
                isBuiltIn: deviceIsBuiltIn(d),
                isOpaque: deviceIsOpaqueSurface(d),
                supportsForce: deviceSupportsForce(d)
            )
        )
    }

    /// Built-in trackpad or external Magic Trackpad — never a Magic Mouse.
    static func isTrackpadDevice(_ d: DeviceRef) -> Bool {
        TouchDeviceClassifier.isTrackpad(classify(d))
    }

    /// Magic Mouse only — never built-in / Force Touch trackpads (would fake tap-to-click).
    static func isMagicMouseDevice(_ d: DeviceRef) -> Bool {
        TouchDeviceClassifier.isMagicMouse(classify(d))
    }

    /// MT contact-state machine: 1 StartInRange, 2 HoverInRange, 3 MakeTouch,
    /// 4 Touching, 5 BreakTouch, 6 LingerInRange, 7 OutOfRange.
    /// Only 3–5 mean the finger is physically ON the surface; 1/2/6/7 are
    /// proximity states — the capacitive sensor sees a finger *hovering above*
    /// the surface without touching it (real taps log state=3→4→…, see sanne.log).
    /// Treating hover as contact caused ghost clicks with no physical touch at all.
    static func isPhysicalContact(_ state: Int32) -> Bool { (3...5).contains(state) }

    static func touch(at base: UnsafeMutableRawPointer, index: Int) -> MTTouchC {
        let p = base.advanced(by: index * MemoryLayout<MTTouchC>.stride)
        return p.assumingMemoryBound(to: MTTouchC.self).pointee
    }
}
