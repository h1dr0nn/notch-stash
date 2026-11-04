@testable import NotchStashCore
import XCTest

final class SubnetSweepTests: XCTestCase {
    func testSlash24SkipsNetworkBroadcastAndSelf() {
        let hosts = SubnetSweep.hosts(address: "192.168.1.20", netmask: "255.255.255.0")
        XCTAssertEqual(hosts.count, 253)
        XCTAssertEqual(hosts.first, "192.168.1.1")
        XCTAssertEqual(hosts.last, "192.168.1.254")
        XCTAssertFalse(hosts.contains("192.168.1.20"))
    }

    func testSlash22CoversNeighbouringBlocks() {
        let hosts = SubnetSweep.hosts(address: "10.10.20.73", netmask: "255.255.252.0")
        XCTAssertEqual(hosts.count, 1021)
        XCTAssertTrue(hosts.contains("10.10.21.5"))
        XCTAssertTrue(hosts.contains("10.10.23.254"))
        XCTAssertFalse(hosts.contains("10.10.24.1"))
    }

    func testWideSubnetsAreNarrowed() {
        let hosts = SubnetSweep.hosts(address: "10.4.9.9", netmask: "255.0.0.0")
        XCTAssertEqual(hosts.count, 1021)
        XCTAssertEqual(hosts.first, "10.4.8.1")
    }

    func testSkipsVPNLinkLocalAndInvalid() {
        XCTAssertTrue(SubnetSweep.hosts(address: "100.106.50.77", netmask: "255.255.255.0").isEmpty)
        XCTAssertTrue(SubnetSweep.hosts(address: "169.254.3.4", netmask: "255.255.0.0").isEmpty)
        XCTAssertTrue(SubnetSweep.hosts(address: "127.0.0.1", netmask: "255.0.0.0").isEmpty)
        XCTAssertTrue(SubnetSweep.hosts(address: "nope", netmask: "255.255.255.0").isEmpty)
        XCTAssertTrue(SubnetSweep.hosts(address: "192.168.1.2", netmask: "255.255.255.255").isEmpty)
    }
}
