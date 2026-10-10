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
    func testSecondsKeepTheirWidthButDroppingHoursShrinks() {
        func width(_ text: String) -> CGFloat {
            CompactMenuBarLabel(text: text, widthTemplate: CompactCountdown.widthTemplate(text: text))
                .renderedImage.size.width
        }
        let secondsWidth = width("59s")
        XCTAssertGreaterThan(secondsWidth, 30)
        for seconds in 0...60 {
            XCTAssertEqual(width("\(seconds)s"), secondsWidth, accuracy: 0.1)
        }
        XCTAssertEqual(width("5h59m"), width("5h58m"), accuracy: 0.1)
        XCTAssertEqual(width("59m"), width("58m"), accuracy: 0.1)
        XCTAssertLessThan(width("59m"), width("1h0m"))
        XCTAssertLessThan(width("9m"), width("10m"))
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
