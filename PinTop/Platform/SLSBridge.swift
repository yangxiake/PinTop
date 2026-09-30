import AppKit
import ObjectiveC

/// Runtime-resolved SkyLight operations. Changes are verified by membership readback.
@MainActor final class SLSBridge {
    enum Failure: Error { case unavailable(String), invalidResult(String) }
    private typealias Allocate = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
    private typealias Initialize = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
    private typealias IDInit = @convention(c) (AnyObject, Selector, UInt64) -> Unmanaged<AnyObject>?
    private typealias OptionsObjectInit = @convention(c) (AnyObject, Selector, UInt32, AnyObject) -> Unmanaged<AnyObject>?
    private typealias IDIntegerInit = @convention(c) (AnyObject, Selector, UInt64, Int32) -> Unmanaged<AnyObject>?
    private typealias IDWindowsOptionsInit = @convention(c) (AnyObject, Selector, UInt64, AnyObject, UInt32) -> Unmanaged<AnyObject>?
    private typealias ObjectInit = @convention(c) (AnyObject, Selector, AnyObject) -> Unmanaged<AnyObject>?
    private typealias ObjectsInit = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Unmanaged<AnyObject>?
    private typealias PerformSync = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
    private typealias PerformAsync = @convention(c) (AnyObject, Selector) -> Void
    private typealias Connection = @convention(c) () -> Int32
    private typealias HitTest = @convention(c) (Int32, Int32, Int32, Int32, UnsafePointer<CGPoint>, UnsafeMutablePointer<CGPoint>, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<Int32>) -> Int32
    private let send: UnsafeMutableRawPointer
    private let perform = NSSelectorFromString("performWithWMBridgeDelegate")

    private func symbol(_ name: String) throws -> UnsafeMutableRawPointer {
        guard let handle = dlopen(nil, RTLD_NOW), let address = dlsym(handle, name) else {
            throw Failure.unavailable(name)
        }
        return address
    }

    init() throws {
        guard dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) != nil,
              let handle = dlopen(nil, RTLD_NOW), let send = dlsym(handle, "objc_msgSend") else {
            throw Failure.unavailable("SkyLight/Objective-C runtime")
        }
        self.send = send
    }

    private func make(_ shortName: String, selector: String,
                      initialize: (AnyObject, Selector) -> Unmanaged<AnyObject>?) throws -> AnyObject {
        guard let cls = NSClassFromString("SLSBridged" + shortName),
              class_getInstanceMethod(cls, NSSelectorFromString(selector)) != nil else {
            throw Failure.unavailable(shortName + " / " + selector)
        }
        let allocate = unsafeBitCast(send, to: Allocate.self)
        guard let object = allocate(cls, NSSelectorFromString("alloc")),
              let result = initialize(object.takeUnretainedValue(), NSSelectorFromString(selector)) else {
            throw Failure.invalidResult(shortName)
        }
        return result.takeRetainedValue()
    }

    private func sync(_ operation: AnyObject, field: String) throws -> Any {
        let function = unsafeBitCast(send, to: PerformSync.self)
        guard let result = function(operation, perform)?.takeUnretainedValue() as? NSObject,
              result.responds(to: NSSelectorFromString(field)),
              let value = result.value(forKey: field) else { throw Failure.invalidResult(field) }
        return value
    }

    private func dispatch(_ operation: AnyObject) {
        let function = unsafeBitCast(send, to: PerformAsync.self)
        function(operation, perform)
    }

    func createOverlay(absoluteLevel: Int32 = 1) throws -> UInt64 {
        let operation: AnyObject
        let initialize = unsafeBitCast(send, to: OptionsObjectInit.self)
        operation = try make("SpaceCreateOperation", selector: "initWithOptions:values:") {
            initialize($0, $1, 1, ["pintop.overlay": true] as NSDictionary)
        }
        guard let number = try sync(operation, field: "spaceID") as? NSNumber,
              number.uint64Value != 0 else { throw Failure.invalidResult("spaceID") }
        let id = number.uint64Value
        do {
            let setLevel = unsafeBitCast(send, to: IDIntegerInit.self)
            dispatch(try make("SpaceSetAbsoluteLevelOperation", selector: "initWithSpaceID:level:") {
                setLevel($0, $1, id, absoluteLevel)
            })
            return id
        } catch { try? destroy(id); throw error }
    }

    func add(_ windows: [UInt32], to space: UInt64) throws {
        let initialize = unsafeBitCast(send, to: IDWindowsOptionsInit.self)
        dispatch(try make("SpaceAddWindowsAndRemoveFromSpacesOperation", selector: "initWithSpaceID:windows:options:") {
            initialize($0, $1, space, windows.map(NSNumber.init(value:)) as NSArray, 0)
        })
    }

    func remove(_ windows: [UInt32], from space: UInt64) throws {
        let initialize = unsafeBitCast(send, to: ObjectsInit.self)
        dispatch(try make("RemoveWindowsFromSpacesOperation", selector: "initWithWindows:spaces:") {
            initialize($0, $1, windows.map(NSNumber.init(value:)) as NSArray, [NSNumber(value: space)] as NSArray)
        })
    }

    func setVisible(_ visible: Bool, space: UInt64) throws {
        let initialize = unsafeBitCast(send, to: ObjectInit.self)
        dispatch(try make(visible ? "ShowSpacesOperation" : "HideSpacesOperation", selector: "initWithSpaces:") {
            initialize($0, $1, [NSNumber(value: space)] as NSArray)
        })
    }

    func destroy(_ space: UInt64) throws {
        try setVisible(false, space: space)
        let initialize = unsafeBitCast(send, to: IDInit.self)
        dispatch(try make("SpaceDestroyOperation", selector: "initWithSpaceID:") { initialize($0, $1, space) })
    }

    func spaces(for windows: [UInt32]) throws -> [UInt64] {
        let initialize = unsafeBitCast(send, to: OptionsObjectInit.self)
        let operation = try make("CopySpacesForWindowsOperation", selector: "initWithOptions:windows:") {
            initialize($0, $1, 15, windows.map(NSNumber.init(value:)) as NSArray)
        }
        guard let numbers = try sync(operation, field: "numbers") as? [NSNumber] else {
            throw Failure.invalidResult("window membership")
        }
        return numbers.map(\.uint64Value)
    }

    func managedDisplaySpaces() throws -> [[String: Any]] {
        let initialize = unsafeBitCast(send, to: Initialize.self)
        let operation = try make("CopyManagedDisplaySpacesOperation", selector: "init") { initialize($0, $1) }
        guard let spaces = try sync(operation, field: "propertyListArray") as? [[String: Any]] else {
            throw Failure.invalidResult("managedDisplaySpaces")
        }
        return spaces
    }

    func window(at point: CGPoint) throws -> UInt32 {
        let connection = unsafeBitCast(try symbol("SLSMainConnectionID"), to: Connection.self)
        let hit = unsafeBitCast(try symbol("SLSFindWindowAndOwner"), to: HitTest.self)
        var screenPoint = point, localPoint = CGPoint.zero
        var window: UInt32 = 0
        var owner: Int32 = 0
        guard hit(connection(), 0, 1, 0, &screenPoint, &localPoint, &window, &owner) == 0 else {
            throw Failure.invalidResult("window hit test")
        }
        return window
    }

}
