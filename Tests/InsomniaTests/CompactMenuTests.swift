import AppKit
import XCTest
@testable import Insomnia

final class CompactMenuTests: XCTestCase {
    func testPowerSummaryOmitsZeroWattsAndUsesConnectedPowerLabel() {
        XCTAssertEqual(StatusLines.power(lidClosed: false, watts: 0, batteryPercent: 100, isCharging: true), "Lid open · 100% · On power")
        XCTAssertEqual(StatusLines.power(lidClosed: true, watts: -4.1, batteryPercent: 82, isCharging: false), "Lid closed · 82% · On battery · 4.1 W")
    }

    func testNetworkSummaryNeverIncludesThePermissionExplanation() {
        XCTAssertEqual(WiFiStatusName.compact(ssid: nil, locationAuthorized: false), "Wi-Fi: name hidden")
        XCTAssertEqual(WiFiStatusName.compact(ssid: "Home", locationAuthorized: true), "Wi-Fi: Home")
        XCTAssertEqual(WiFiStatusName.compact(ssid: nil, locationAuthorized: true), "Wi-Fi: unavailable")
    }

    @MainActor
    func testLongStatusWrapsAndQuitHasBottomInset() {
        let message = String(repeating: "A detailed recovery error. ", count: 10)
        let menu = StatusMenu.menu([
            .init(title: message, kind: .warning),
            .init(title: StatusMenu.quitTitle, kind: .quit),
        ], target: nil, settings: #selector(NSObject.description), quit: #selector(NSApplication.terminate(_:)), relaunchBrowser: #selector(NSObject.description), stopWaitingForOutput: #selector(NSObject.description))
        XCTAssertEqual(menu.items[0].title, message, "Keep the complete recovery information")
        XCTAssertLessThanOrEqual(menu.items[0].view?.frame.width ?? .infinity, 308)
        XCTAssertGreaterThan(menu.items[0].view?.frame.height ?? 0, 30)
        let label = try! XCTUnwrap(menu.items[0].view?.subviews.first as? NSTextField)
        let needed = label.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: label.frame.width, height: .greatestFiniteMagnitude))
        XCTAssertGreaterThanOrEqual(label.frame.height, ceil(needed.height), "Every wrapped warning line must fit")
        XCTAssertEqual(menu.items[1].keyEquivalent, "q")
        XCTAssertEqual(menu.items.last?.view?.frame.height, 4)
        XCTAssertFalse(menu.items.last?.isEnabled ?? true)
    }
}
