import AppKit
import XCTest
@testable import Insomnia

final class StatusHostViewportTests: XCTestCase {
    @MainActor
    func testViewportShrinksAfterClosingDurationEntry() {
        _ = NSApplication.shared
        let harness = Harness()
        defer { harness.home.destroy() }
        let root = StatusRootView(model: MenuBarModel(), manager: harness.makeManager(), onTapIcon: {}, onTapPill: { _ in }, onTapCountdown: {}, onEndSession: {}, onWidthChange: { _ in })
        let host = StatusItemController.makeHostingView(root)
        host.frame = NSRect(x: 0, y: 0, width: 180, height: 22)
        host.resizeForStatusItem(80)
        XCTAssertEqual(host.frame.width, 80)
        XCTAssertEqual(host.bounds.width, 80)
        host.resizeForStatusItem(17)
        XCTAssertEqual(host.frame.width, 17)
        XCTAssertEqual(host.bounds.width, 17)
    }
}
