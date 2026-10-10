import XCTest
import IOKit.pwr_mgt
@testable import Insomnia

final class DisplayAwakeTests: XCTestCase {
    func testPreferenceDefaultsOffAndRoundTrips() throws {
        XCTAssertFalse(try JSONDecoder().decode(Config.self, from: Data("{}".utf8)).keepDisplayAwake)
        var config = Config()
        config.keepDisplayAwake = true
        XCTAssertTrue(try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config)).keepDisplayAwake)
        config.keepDisplayAwake = false
        XCTAssertFalse(try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config)).keepDisplayAwake)
    }

    @MainActor
    func testHoldFollowsSessionPreferenceAndLidAndIsIdempotent() {
        var creates = 0
        var released: [IOPMAssertionID] = []
        let guarder = DisplayAwakeGuard(create: { creates += 1; return IOPMAssertionID(creates) }, release: { released.append($0); return true })
        guarder.update(active: false, enabled: true, lidClosed: false)
        guarder.update(active: true, enabled: false, lidClosed: false)
        guarder.update(active: true, enabled: true, lidClosed: true)
        XCTAssertEqual(creates, 0)
        guarder.update(active: true, enabled: true, lidClosed: false)
        guarder.update(active: true, enabled: true, lidClosed: false)
        XCTAssertEqual(creates, 1)
        guarder.update(active: true, enabled: true, lidClosed: true)
        XCTAssertEqual(released, [1])
        guarder.update(active: true, enabled: true, lidClosed: false)
        guarder.update(active: true, enabled: false, lidClosed: false)
        XCTAssertEqual(released, [1, 2])
        guarder.update(active: true, enabled: true, lidClosed: false)
        guarder.update(active: false, enabled: true, lidClosed: false)
        XCTAssertEqual(released, [1, 2, 3])
    }

    @MainActor
    func testFailedAcquisitionCanRetry() {
        var creates = 0
        let guarder = DisplayAwakeGuard(create: { creates += 1; return creates == 1 ? nil : 42 }, release: { _ in true })
        guarder.update(active: true, enabled: true, lidClosed: false)
        guarder.update(active: true, enabled: true, lidClosed: false)
        guarder.update(active: true, enabled: true, lidClosed: false)
        XCTAssertEqual(creates, 2)
    }
    @MainActor
    func testFailedReleaseRetainsOwnershipForRetry() {
        var creates = 0
        var releases: [IOPMAssertionID] = []
        let guarder = DisplayAwakeGuard(create: { creates += 1; return 7 }, release: {
            releases.append($0)
            return releases.count > 1
        })
        guarder.update(active: true, enabled: true, lidClosed: false)
        guarder.update(active: false, enabled: true, lidClosed: false)
        guarder.update(active: true, enabled: true, lidClosed: false)
        XCTAssertEqual(creates, 1)
        guarder.update(active: false, enabled: true, lidClosed: false)
        XCTAssertEqual(releases, [7, 7])
    }

}
