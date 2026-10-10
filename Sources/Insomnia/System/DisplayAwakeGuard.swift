import Foundation
import IOKit.pwr_mgt

@MainActor
protocol DisplayAwakeGuarding {
    func update(active: Bool, enabled: Bool, lidClosed: Bool)
}

/// Tests and nonproduction service wiring must never acquire a desktop assertion.
struct NoopDisplayAwakeGuard: DisplayAwakeGuarding {
    func update(active: Bool, enabled: Bool, lidClosed: Bool) {}
}

/// A process-owned assertion: no power preference writes, sudo, or recovery
/// journal. macOS releases it if the app exits. It does not wake an off display.
@MainActor
final class DisplayAwakeGuard: DisplayAwakeGuarding {
    private var assertion: IOPMAssertionID?
    private let create: () -> IOPMAssertionID?
    private let release: (IOPMAssertionID) -> Bool

    init(create: @escaping () -> IOPMAssertionID?, release: @escaping (IOPMAssertionID) -> Bool) {
        self.create = create
        self.release = release
    }

    convenience init() {
        self.init(create: {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Insomnia: keep display awake during session" as CFString,
                &id
            )
            guard result == kIOReturnSuccess else {
                Log.error("could not keep display awake: IOPM assertion returned \(result)")
                return nil
            }
            return id
        }, release: { id in
            let result = IOPMAssertionRelease(id)
            if result != kIOReturnSuccess {
                Log.error("could not release display-awake assertion: \(result)")
            }
            return result == kIOReturnSuccess
        })
    }

    func update(active: Bool, enabled: Bool, lidClosed: Bool) {
        if active && enabled && !lidClosed {
            if assertion == nil { assertion = create() }
        } else if let id = assertion, release(id) {
            assertion = nil
        }
    }
}
