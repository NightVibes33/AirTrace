import XCTest
@testable import AirTrace

final class AirTraceTests: XCTestCase {
    func testParsesAirPodsProAdvertisementWithCompanyIdentifier() {
        let payload: [UInt8] = [
            0x4C, 0x00,
            0x07, 0x19, 0x01, 0x0E, 0x20,
            0x62, 0xA7, 0xB3, 0x09, 0x00, 0x04,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ]
        let parsed = AirPodsPacketParser.parse(manufacturerData: Data(payload), rssi: -51)
        XCTAssertEqual(parsed?.model, .airPodsPro)
        XCTAssertEqual(parsed?.rssi, -51)
        XCTAssertNotNil(parsed?.leftBattery)
    }

    func testParsesAirPodsPro3Model() {
        let payload: [UInt8] = [
            0x07, 0x19, 0x01, 0x27, 0x20,
            0x10, 0x88, 0x80, 0x00, 0x00, 0x04,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ]
        let parsed = AirPodsPacketParser.parse(manufacturerData: Data(payload), rssi: -60)
        XCTAssertEqual(parsed?.model, .airPodsPro3)
    }

    func testRejectsBeatsProximityPacket() {
        let payload: [UInt8] = [
            0x07, 0x19, 0x01, 0x11, 0x20,
            0x00, 0x88, 0x80, 0x00, 0x00, 0x04,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ]
        XCTAssertNil(AirPodsPacketParser.parse(manufacturerData: Data(payload), rssi: -45))
    }

    func testRejectsNonProximityApplePacket() {
        let payload = Data([0x4C, 0x00, 0x12, 0x19, 0x01, 0x0E, 0x20])
        XCTAssertNil(AirPodsPacketParser.parse(manufacturerData: payload, rssi: -45))
    }

    func testRSSIDistanceIsMonotonic() {
        let engine = LocalizationEngine()
        engine.reset(referenceRSSI: -52, mode: .guided)
        let near = engine.estimatedDistance(forRSSI: -55)
        let far = engine.estimatedDistance(forRSSI: -75)
        XCTAssertLessThan(near, far)
    }
}
