import Foundation
import CoreBluetooth

struct AirPodsPacketParser {
    static func parse(manufacturerData: Data, rssi: Int, timestamp: TimeInterval = Date().timeIntervalSince1970) -> AirPodsAdvertisement? {
        guard rssi != 127 else { return nil }
        var bytes = [UInt8](manufacturerData)

        // CoreBluetooth commonly includes Apple's little-endian company ID in
        // CBAdvertisementDataManufacturerDataKey. Accept payload-only captures too.
        if bytes.count >= 2, bytes[0] == 0x4C, bytes[1] == 0x00 {
            bytes.removeFirst(2)
        }

        guard bytes.count >= 5, bytes[0] == 0x07 else { return nil }
        let modelCode = (UInt16(bytes[3]) << 8) | UInt16(bytes[4])
        guard let model = AirPodsModel(rawValue: modelCode) else { return nil }

        let mode = bytes[2]
        var left: Int?
        var right: Int?
        var caseBattery: Int?
        var lidOpen: Bool?

        if bytes.count > 8 {
            let podBattery = bytes[6]
            left = AirPodsAdvertisement.batteryPercent(nibble: podBattery >> 4)
            right = AirPodsAdvertisement.batteryPercent(nibble: podBattery & 0x0F)
            let caseAndFlags = bytes[7]
            caseBattery = AirPodsAdvertisement.batteryPercent(nibble: caseAndFlags >> 4)
            let lid = bytes[8]
            lidOpen = (lid & 0x08) == 0
        }

        return AirPodsAdvertisement(
            model: model,
            modelCode: modelCode,
            pairingMode: mode,
            rssi: rssi,
            timestamp: timestamp,
            leftBattery: left,
            rightBattery: right,
            caseBattery: caseBattery,
            lidOpen: lidOpen,
            rawPayload: Data(bytes)
        )
    }
}

/// Parser for Apple's Offline Finding / Find My BLE frame (type 0x12).
/// The status byte uses bits 4...5 as the device class. AirGuard and
/// FindMy.py both identify value 3 (0b11) as AirPods.
struct FindMyAirPodsPacketParser {
    struct Parsed {
        let statusByte: UInt8
        let state: FindMyAirPodsBeacon.State
        let batteryLevel: Int?
        let payload: Data
    }

    static func parse(manufacturerData: Data, rssi: Int) -> Parsed? {
        guard rssi != 127, rssi < 0 else { return nil }
        var bytes = [UInt8](manufacturerData)

        if bytes.count >= 2, bytes[0] == 0x4C, bytes[1] == 0x00 {
            bytes.removeFirst(2)
        }

        // Find My frame: [0x12, payloadLength, status, ...]
        guard bytes.count >= 3, bytes[0] == 0x12 else { return nil }
        let declaredLength = bytes[1]
        let status = bytes[2]
        let deviceType = (status & 0x30) >> 4
        guard deviceType == 0x03 else { return nil } // AirPods only

        let state: FindMyAirPodsBeacon.State
        switch declaredLength {
        case 0x02:
            state = .nearby
        case 0x19:
            state = .separated
        default:
            state = .unknown
        }

        // Find My status bits 6...7 are a four-level battery state, not a
        // precise percentage. Approximate percentages are for display only.
        let batteryCode = (status & 0xC0) >> 6
        let battery: Int?
        switch batteryCode {
        case 0: battery = 100
        case 1: battery = 66
        case 2: battery = 33
        case 3: battery = 10
        default: battery = nil
        }

        return Parsed(
            statusByte: status,
            state: state,
            batteryLevel: battery,
            payload: Data(bytes)
        )
    }

    static func applePacketType(manufacturerData: Data) -> UInt8? {
        var bytes = [UInt8](manufacturerData)
        if bytes.count >= 2, bytes[0] == 0x4C, bytes[1] == 0x00 {
            bytes.removeFirst(2)
        }
        return bytes.first
    }
}

final class AirPodsScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var candidates: [DiscoveredAirPods] = []
    @Published private(set) var findMyBeacons: [FindMyAirPodsBeacon] = []
    @Published private(set) var applePacketTypeCounts: [UInt8: Int] = [:]
    @Published private(set) var totalApplePackets = 0
    @Published private(set) var isScanning = false
    @Published private(set) var lastPacketAt: Date?

    var onAirPodsObservation: ((DiscoveredAirPods) -> Void)?
    var onFindMyObservation: ((FindMyAirPodsBeacon) -> Void)?

    private var central: CBCentralManager!
    private var wantsScanning = false
    private var firstSeen: [UUID: Date] = [:]
    private var findMyFirstSeen: [UUID: Date] = [:]
    private var findMyPacketCounts: [UUID: Int] = [:]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    func start() {
        wantsScanning = true
        startIfPossible()
    }

    func stop() {
        wantsScanning = false
        if central.isScanning { central.stopScan() }
        isScanning = false
    }

    func clearCandidates() {
        candidates.removeAll()
        findMyBeacons.removeAll()
        firstSeen.removeAll()
        findMyFirstSeen.removeAll()
        findMyPacketCounts.removeAll()
        applePacketTypeCounts.removeAll()
        totalApplePackets = 0
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn {
            startIfPossible()
        } else {
            isScanning = false
        }
    }

    private func startIfPossible() {
        guard wantsScanning, central.state == .poweredOn, !central.isScanning else { return }
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        guard let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else { return }

        let rssi = RSSI.intValue
        if isAppleManufacturerData(manufacturer) {
            totalApplePackets += 1
            if let type = FindMyAirPodsPacketParser.applePacketType(manufacturerData: manufacturer) {
                applePacketTypeCounts[type, default: 0] += 1
            }
        }

        // PRIMARY PATH: closed-case/lost AirPods Find My advertisements (0x12).
        if let parsed = FindMyAirPodsPacketParser.parse(manufacturerData: manufacturer, rssi: rssi) {
            publishFindMyAirPods(peripheralID: peripheral.identifier, parsed: parsed, rssi: rssi)
        }

        // LEGACY/FALLBACK PATH: AirPods proximity-pairing packet (0x07).
        if let ad = AirPodsPacketParser.parse(manufacturerData: manufacturer, rssi: rssi) {
            publishProximityAirPods(peripheralID: peripheral.identifier, advertisement: ad)
        }
    }

    private func isAppleManufacturerData(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        // When company ID is present, require Apple 0x004C. Some platform
        // variants strip it before delivering manufacturer payload.
        if bytes.count >= 2 {
            return bytes[0] == 0x4C && bytes[1] == 0x00
                || bytes[0] == 0x07
                || bytes[0] == 0x12
        }
        return false
    }

    private func publishFindMyAirPods(
        peripheralID: UUID,
        parsed: FindMyAirPodsPacketParser.Parsed,
        rssi: Int
    ) {
        let now = Date()
        let first = findMyFirstSeen[peripheralID] ?? now
        if findMyFirstSeen[peripheralID] == nil { findMyFirstSeen[peripheralID] = now }
        let count = (findMyPacketCounts[peripheralID] ?? 0) + 1
        findMyPacketCounts[peripheralID] = count

        let beacon = FindMyAirPodsBeacon(
            id: peripheralID,
            peripheralID: peripheralID,
            rssi: rssi,
            statusByte: parsed.statusByte,
            state: parsed.state,
            batteryLevel: parsed.batteryLevel,
            rawPayload: parsed.payload,
            firstSeen: first,
            lastSeen: now,
            packetCount: count
        )

        if let index = findMyBeacons.firstIndex(where: { $0.peripheralID == peripheralID }) {
            findMyBeacons[index] = beacon
        } else {
            findMyBeacons.append(beacon)
        }
        findMyBeacons.removeAll { now.timeIntervalSince($0.lastSeen) > 45 }
        findMyBeacons.sort { lhs, rhs in
            if lhs.rssi == rhs.rssi { return lhs.lastSeen > rhs.lastSeen }
            return lhs.rssi > rhs.rssi
        }

        lastPacketAt = now
        onFindMyObservation?(beacon)
    }

    private func publishProximityAirPods(peripheralID: UUID, advertisement ad: AirPodsAdvertisement) {
        let now = Date()
        let discovered = DiscoveredAirPods(
            id: peripheralID,
            peripheralID: peripheralID,
            advertisement: ad,
            firstSeen: firstSeen[peripheralID] ?? now,
            lastSeen: now
        )
        if firstSeen[peripheralID] == nil { firstSeen[peripheralID] = now }

        if let index = candidates.firstIndex(where: { $0.peripheralID == peripheralID }) {
            candidates[index] = discovered
        } else {
            candidates.append(discovered)
        }
        candidates.sort { lhs, rhs in
            if lhs.rssi == rhs.rssi { return lhs.lastSeen > rhs.lastSeen }
            return lhs.rssi > rhs.rssi
        }
        lastPacketAt = now
        onAirPodsObservation?(discovered)
    }

    func bestMatch(for target: TargetProfile) -> DiscoveredAirPods? {
        let sameModel = candidates.filter { $0.model == target.model }
        if let savedID = target.peripheralID,
           let exact = sameModel.first(where: { $0.peripheralID == savedID }) {
            return exact
        }
        return sameModel.max(by: { $0.rssi < $1.rssi })
    }

    func rssi(for target: TargetProfile) -> Int? {
        bestMatch(for: target)?.rssi
    }

    func findMyBeacon(id: UUID) -> FindMyAirPodsBeacon? {
        findMyBeacons.first(where: { $0.peripheralID == id })
    }
}
