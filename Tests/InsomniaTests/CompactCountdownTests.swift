import XCTest
import AppKit
import SwiftUI
@testable import Insomnia

final class CompactCountdownTests: XCTestCase {
    func testUnitsAndBoundaries() {
        XCTAssertEqual(CompactCountdown.text(remaining: 6 * 3600 - 15), "5h59m")
        XCTAssertEqual(CompactCountdown.text(remaining: 3600), "1h0m")
        XCTAssertEqual(CompactCountdown.text(remaining: 3599), "59m")
        XCTAssertEqual(CompactCountdown.text(remaining: 60), "1m")
        XCTAssertEqual(CompactCountdown.text(remaining: 59.5), "60s")
        XCTAssertEqual(CompactCountdown.text(remaining: 59), "59s")
        XCTAssertEqual(CompactCountdown.text(remaining: 0), "0s")
        XCTAssertEqual(CompactCountdown.text(remaining: -1), "0s")
    }

    @MainActor
    func testLabelWidthRemainsStableThroughUnitAndDigitChanges() {
        for duration in [3600.0 * 6, 3600.0 * 12, 86400.0 * 30, 1800.0] {
            let template = CompactCountdown.widthTemplate(duration: duration)
            let widths = [duration, duration - 1, 3600, 3599, 600, 599, 60, 59, 10, 9, 0].map { remaining in
                let label = CompactMenuBarLabel(
                    text: CompactCountdown.text(remaining: min(remaining, duration)),
                    widthTemplate: template
                )
                return label.renderedImage.size.width
            }
            XCTAssertGreaterThan(widths[0], 30)
            for width in widths { XCTAssertEqual(width, widths[0], accuracy: 0.1) }
        }
    }
    @MainActor
    func testCompactTextUsesTheEngineClockAndClearsAfterEnd() async throws {
        let h = Harness()
        defer { h.home.destroy() }
        let manager = h.makeManager()
        await manager.start(duration: 6 * 3600)
        manager.pauseCountdown()
        XCTAssertEqual(manager.compactCountdownText, "6h0m")
        h.clock.advance(15)
        manager.refreshCountdown()
        XCTAssertEqual(manager.compactCountdownText, "5h59m")
        h.clock.advance(6 * 3600 - 15 - 59)
        manager.refreshCountdown()
        XCTAssertEqual(manager.compactCountdownText, "59s")
        _ = await manager.end(reason: .user)
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.compactCountdownText, "")
    }

}
