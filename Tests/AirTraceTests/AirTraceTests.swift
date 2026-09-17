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
        let payload = Data([0x4C, 0x00, 0x12, 0x19, 0x30, 0xAA, 0xBB])
        XCTAssertNil(AirPodsPacketParser.parse(manufacturerData: payload, rssi: -45))
    }

    func testParsesSeparatedFindMyAirPodsFrame() {
        let payload = Data([
            0x4C, 0x00,
            0x12, 0x19,
            0x70, // battery=medium, device type bits=0b11 (AirPods)
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77
        ])
        let parsed = FindMyAirPodsPacketParser.parse(manufacturerData: payload, rssi: -63)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.state, .separated)
        XCTAssertEqual((parsed!.statusByte & 0x30) >> 4, 3)
        XCTAssertEqual(parsed?.batteryLevel, 66)
    }

    func testParsesNearbyFindMyAirPodsFrame() {
        let payload = Data([0x12, 0x02, 0x30, 0xC0])
        let parsed = FindMyAirPodsPacketParser.parse(manufacturerData: payload, rssi: -48)
        XCTAssertEqual(parsed?.state, .nearby)
    }

    func testFindMyParserRejectsAirTagType() {
        let payload = Data([0x4C, 0x00, 0x12, 0x19, 0x10, 0xAA, 0xBB])
        XCTAssertNil(FindMyAirPodsPacketParser.parse(manufacturerData: payload, rssi: -52))
    }

    func testFindMyPacketTypeDiagnostic() {
        let payload = Data([0x4C, 0x00, 0x12, 0x19, 0x30])
        XCTAssertEqual(FindMyAirPodsPacketParser.applePacketType(manufacturerData: payload), 0x12)
    }

    func testRSSIDistanceIsMonotonic() {
        let engine = LocalizationEngine()
        engine.reset(referenceRSSI: -52, mode: .guided)
        let near = engine.estimatedDistance(forRSSI: -55)
        let far = engine.estimatedDistance(forRSSI: -75)
        XCTAssertLessThan(near, far)
    }
}
