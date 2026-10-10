import AppKit
import SwiftUI
import XCTest
@testable import Insomnia

final class SettingsWindowGlassTests: XCTestCase {
    @MainActor
    func testNativeGlassBackdropCoversTheTitlebarOffscreen() throws {
        _ = NSApplication.shared
        let owner = SettingsWindow { AnyView(Text("Settings").frame(width: 680, height: 480)) }
        let window = owner.make()
        defer { window.close() }
        window.contentView?.layoutSubtreeIfNeeded()
        let glass = try XCTUnwrap(window.contentView as? NSGlassEffectView)
        XCTAssertEqual(glass.style, .clear)
        XCTAssertNotNil(glass.contentView)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(glass.bounds.width, window.frame.width, accuracy: 1)
        XCTAssertEqual(glass.bounds.height, window.frame.height, accuracy: 1, "No transparent hole behind the title bar")
        XCTAssertFalse(window.isVisible, "Verification must never open a window on the desktop")
    }
}
