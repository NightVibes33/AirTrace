import Foundation
import CoreBluetooth

struct AirPodsPacketParser {
    static func parse(manufacturerData: Data, rssi: Int, timestamp: TimeInterval = Date().timeIntervalSince1970) -> AirPodsAdvertisement? {
        guard rssi != 127 else { return nil }
        var bytes = [UInt8](manufacturerData)

        // Some BLE stacks include Apple's little-endian company ID (0x004C)
        // in the manufacturer blob and some hand us only the payload. Accept both.
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

final class AirPodsScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var candidates: [DiscoveredAirPods] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastPacketAt: Date?

    var onAirPodsObservation: ((DiscoveredAirPods) -> Void)?

    private var central: CBCentralManager!
    private var wantsScanning = false
    private var firstSeen: [UUID: Date] = [:]

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
        firstSeen.removeAll()
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
        guard let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              let ad = AirPodsPacketParser.parse(manufacturerData: manufacturer, rssi: RSSI.intValue)
        else { return }

        let now = Date()
        let id = peripheral.identifier
        let discovered = DiscoveredAirPods(
            id: id,
            peripheralID: id,
            advertisement: ad,
            firstSeen: firstSeen[id] ?? now,
            lastSeen: now
        )
        if firstSeen[id] == nil { firstSeen[id] = now }

        if let index = candidates.firstIndex(where: { $0.peripheralID == id }) {
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
}
