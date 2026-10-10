import AppKit
import XCTest
@testable import Insomnia

final class ApplicationBundleTests: XCTestCase {
    private func makeBundle(in directory: URL, name: String, identifier: String?, packageType: String = "APPL") throws -> URL {
        let url = directory.appendingPathComponent(name)
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        var info = ["CFBundlePackageType": packageType, "CFBundleName": "Example"]
        if let identifier { info["CFBundleIdentifier"] = identifier }
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return url
    }

    func testOnlyLocalApplicationsWithIdentifiersAreAccepted() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let app = try makeBundle(in: home, name: "Example.app", identifier: "test.example")
        let folder = try makeBundle(in: home, name: "Folder", identifier: "test.folder")
        let missing = try makeBundle(in: home, name: "Missing.app", identifier: nil)
        let blank = try makeBundle(in: home, name: "Blank.app", identifier: " ")
        let resource = try makeBundle(in: home, name: "Resource.app", identifier: "test.resource", packageType: "BNDL")
        XCTAssertEqual(ApplicationBundles.identifier(at: app), "test.example")
        XCTAssertNil(ApplicationBundles.identifier(at: folder))
        XCTAssertNil(ApplicationBundles.identifier(at: missing))
        XCTAssertNil(ApplicationBundles.identifier(at: blank))
        XCTAssertNil(ApplicationBundles.identifier(at: resource))
        XCTAssertNil(ApplicationBundles.identifier(at: URL(string: "https://example.com/Example.app")!))
    }

    func testMultipleApplicationCopiesAreDeduplicatedAndInvalidDropsIgnored() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let first = try makeBundle(in: home, name: "First.app", identifier: "test.same")
        let copy = try makeBundle(in: home, name: "Copy.app", identifier: "test.same")
        let second = try makeBundle(in: home, name: "Second.app", identifier: "test.second")
        XCTAssertEqual(ApplicationBundles.identifiers(in: [first, copy, home, second]), ["test.same", "test.second"])
    }

    @MainActor
    func testUnavailableApplicationsStillHaveDisplayMetadata() {
        let app = ApplicationBundles.presentation(for: "test.not.installed")
        XCTAssertFalse(app.name.isEmpty)
        XCTAssertGreaterThan(app.icon.size.width, 0)
    }

    func testKnownAbsentDefaultsHaveFriendlyNames() {
        XCTAssertEqual(ApplicationBundles.knownNames["io.tailscale.ipn.macsys"], "Tailscale")
        XCTAssertEqual(ApplicationBundles.knownNames["ai.elementlabs.lmstudio"], "LM Studio")
        XCTAssertEqual(ApplicationBundles.knownNames["com.docker.docker"], "Docker Desktop")
        XCTAssertTrue((Config.defaultAgentList + Config.defaultFreezeList).allSatisfy { ApplicationBundles.knownNames[$0] != nil })
    }

    func testInstalledAgentHostsAndInfrastructureAreProtectedFromAutomaticPausing() {
        let identifiers = ["company.thebrowser.dia", "ai.opencode.desktop", "com.termius-dmg.mac", "com.wireguard.macos", "com.utmapp.UTM", "io.tailscale.ipn.macos"]
        for identifier in identifiers {
            XCTAssertTrue(FreezePlanner.isBuiltInProtected(identifier), identifier)
        }
    }
}
