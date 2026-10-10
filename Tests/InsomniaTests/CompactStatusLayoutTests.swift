import AppKit
import SwiftUI
import XCTest
@testable import Insomnia

/// Measure the content offscreen, without creating a live NSStatusItem.
final class CompactStatusLayoutTests: XCTestCase {
    @MainActor
    private func width(model: MenuBarModel, manager: SessionManager) -> CGFloat {
        let root = StatusRootView(model: model, manager: manager, onTapIcon: {}, onTapPill: { _ in }, onTapCountdown: {}, onEndSession: {}, onWidthChange: { _ in })
        return NSHostingView(rootView: root).fittingSize.width
    }

    @MainActor
    func testIdleReservesOnlyTheSeventeenPointIcon() {
        _ = NSApplication.shared
        let harness = Harness()
        defer { harness.home.destroy() }
        XCTAssertEqual(width(model: MenuBarModel(), manager: harness.makeManager()), 17, accuracy: 0.01)
    }

    @MainActor
    func testRunningTwentyMinuteTimerFitsWithinEightyOnePoints() async {
        _ = NSApplication.shared
        let harness = Harness()
        defer { harness.home.destroy() }
        let manager = harness.makeManager()
        await manager.start(duration: 20 * 60)
        let model = MenuBarModel()
        model.phase = .running
        XCTAssertTrue(manager.isActive)
        XCTAssertLessThanOrEqual(width(model: model, manager: manager), 81)
        await manager.end(reason: .user)
    }

    @MainActor
    func testEnteringValuesDoesNotGrowTheInputLayout() {
        _ = NSApplication.shared
        let harness = Harness()
        defer { harness.home.destroy() }
        let manager = harness.makeManager()
        let model = MenuBarModel()
        model.phase = .entering(.start)
        model.slotsPresent = true
        model.visiblePills = 3
        let empty = width(model: model, manager: manager)
        model.input = DurationInput(days: 30, hours: 23, minutes: 59)
        XCTAssertEqual(width(model: model, manager: manager), empty, accuracy: 0.01)
    }
}
