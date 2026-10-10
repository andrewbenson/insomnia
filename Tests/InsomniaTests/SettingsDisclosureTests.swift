import AppKit
import SwiftUI
import XCTest
@testable import Insomnia

final class SettingsDisclosureTests: XCTestCase {
    @MainActor
    func testExpandedSectionsActuallyRevealTheirContent() {
        _ = NSApplication.shared
        let collapsed = SettingsDisclosure("Details", isExpanded: .constant(false)) {
            Text("Useful settings").frame(height: 80)
        }
        let expanded = SettingsDisclosure("Details", isExpanded: .constant(true)) {
            Text("Useful settings").frame(height: 80)
        }
        let closedHeight = NSHostingView(rootView: collapsed.frame(width: 300)).fittingSize.height
        let openHeight = NSHostingView(rootView: expanded.frame(width: 300)).fittingSize.height
        XCTAssertGreaterThanOrEqual(openHeight - closedHeight, 80)
    }
}
