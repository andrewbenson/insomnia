import AppKit
import SwiftUI
import XCTest
@testable import Insomnia

/// Offscreen only: no status items, focus panels, or displayed windows.
final class SettingsLayoutTests: XCTestCase {
    @MainActor
    private struct LoginService: LoginItemServicing {
        var status: LoginItemStatus { .notRegistered }
        func register() throws {}
        func unregister() throws {}
        func openSystemSettingsLoginItems() {}
    }

    @MainActor
    func testEveryPageFitsTheCompactWindowOffscreen() async throws {
        _ = NSApplication.shared
        let appearance = NSApp.appearance
        NSApp.appearance = NSAppearance(named: .darkAqua)
        defer { NSApp.appearance = appearance }
        let harness = Harness()
        defer { harness.home.destroy() }
        let manager = harness.makeManager()
        let previews = ProcessInfo.processInfo.environment["INSOMNIA_SETTINGS_PREVIEW_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let previews { try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true) }
        for page in SettingsView.Page.allCases {
            let root = SettingsView(manager: manager, secrets: InMemoryHotspotSecretStore(), locationPermission: LocationPermission(authorizationStatus: .notDetermined, request: {}), loginItem: LoginItem(service: LoginService(), install: "test", activity: NotificationCenter()), initialPage: page)
            let owner = SettingsWindow { AnyView(root.environment(\.colorScheme, .dark)) }
            let window = owner.make()
            let host = try XCTUnwrap(window.contentView)
            window.appearance = NSAppearance(named: .darkAqua)
            host.layoutSubtreeIfNeeded()
            await Task.yield()
            XCTAssertEqual(window.contentLayoutRect.width, 680, accuracy: 1, page.rawValue)
            XCTAssertEqual(window.contentLayoutRect.height, 480, accuracy: 1, page.rawValue)
            XCTAssertFalse(window.isVisible, "The preview must never appear on the user's desktop")
            if let previews, let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try data.write(to: previews.appendingPathComponent("\(page.id).png"))
                }
            }
            window.close()
        }
    }
}
