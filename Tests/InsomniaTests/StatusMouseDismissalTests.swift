import CoreGraphics
import XCTest
@testable import Insomnia

final class StatusMouseDismissalTests: XCTestCase {
    func testFieldClicksKeepEditorOpenEvenWithoutAnAppWindowIdentity() {
        let frame = CGRect(x: 800, y: 1000, width: 200, height: 38)
        for x in [825.0, 890.0, 955.0] {
            XCTAssertFalse(StatusMouseDismissal.shouldDismiss(isOwnWindow: false, location: CGPoint(x: x, y: 1015), statusFrame: frame))
        }
    }

    func testOutsideClicksDismissAndOwnWindowClicksDoNot() {
        let frame = CGRect(x: 800, y: 1000, width: 200, height: 38)
        XCTAssertTrue(StatusMouseDismissal.shouldDismiss(isOwnWindow: false, location: CGPoint(x: 790, y: 1015), statusFrame: frame))
        XCTAssertTrue(StatusMouseDismissal.shouldDismiss(isOwnWindow: false, location: CGPoint(x: 890, y: 900), statusFrame: frame))
        XCTAssertFalse(StatusMouseDismissal.shouldDismiss(isOwnWindow: true, location: .zero, statusFrame: nil))
        XCTAssertTrue(StatusMouseDismissal.shouldDismiss(isOwnWindow: false, location: .zero, statusFrame: nil))
    }
}
