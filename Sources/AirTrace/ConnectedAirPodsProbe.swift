import Foundation
import AVFAudio
import Combine

struct ConnectedAirPodsRecord: Identifiable {
    let id: String
    let source: String
    let name: String
    let connected: Bool
    let genuineAirPods: Bool
    let rssi: Int?
    let productID: UInt64?
    let caseBattery: Double?
    let leftBattery: Double?
    let rightBattery: Double?
    let findMyCaseIdentifier: String?
    let raw: [String: Any]

    static func hpm(_ dict: [String: Any], index: Int, connected: Bool) -> ConnectedAirPodsRecord {
        let cb = dict["cbDevice"] as? [String: Any] ?? [:]
        let name = (dict["name"] as? String)
            ?? (cb["productName"] as? String)
            ?? (cb["name"] as? String)
            ?? "HeadphoneManager device"
        let address = (dict["btAddress"] as? String)
            ?? (cb["identifier"] as? String)
            ?? "hpm-\(index)"
        return ConnectedAirPodsRecord(
            id: "hpm-\(address)",
            source: "HeadphoneManager",
            name: name,
            connected: connected,
            genuineAirPods: (dict["isAirpods"] as? NSNumber)?.boolValue ?? false,
            rssi: (cb["bleRSSI"] as? NSNumber)?.intValue,
            productID: (cb["productID"] as? NSNumber)?.uint64Value,
            caseBattery: (dict["batteryLevelCase"] as? NSNumber)?.doubleValue,
            leftBattery: (dict["batteryLevelLeft"] as? NSNumber)?.doubleValue,
            rightBattery: (dict["batteryLevelRight"] as? NSNumber)?.doubleValue,
            findMyCaseIdentifier: cb["findMyCaseIdentifier"] as? String,
            raw: dict
        )
    }

    static func btm(_ dict: [String: Any], index: Int, connected: Bool) -> ConnectedAirPodsRecord {
        let address = (dict["address"] as? String) ?? "btm-\(index)"
        return ConnectedAirPodsRecord(
            id: "btm-\(address)",
            source: "BluetoothManager",
            name: (dict["name"] as? String) ?? (dict["productName"] as? String) ?? "Bluetooth device",
            connected: connected,
            genuineAirPods: (dict["isGenuineAirPods"] as? NSNumber)?.boolValue
                ?? (dict["isAppleAudioDevice"] as? NSNumber)?.boolValue
                ?? false,
            rssi: nil,
            productID: (dict["productId"] as? NSNumber)?.uint64Value,
            caseBattery: nil,
            leftBattery: nil,
            rightBattery: nil,
            findMyCaseIdentifier: nil,
            raw: dict
        )
    }
}

@MainActor
final class ConnectedAirPodsProbeModel: ObservableObject {
    @Published private(set) var records: [ConnectedAirPodsRecord] = []
    @Published private(set) var audioRoutes: [String] = []
    @Published private(set) var headphoneManagerLoaded = false
    @Published private(set) var bluetoothManagerLoaded = false
    @Published private(set) var headphoneManagerInstance = false
    @Published private(set) var bluetoothManagerInstance = false
    @Published private(set) var status = "Not started"
    @Published private(set) var rawJSON = ""

    private let bridge = ATConnectedAirPodsProbe()
    private var timer: Timer?

    var connectedAirPods: [ConnectedAirPodsRecord] {
        records.filter { $0.connected && $0.genuineAirPods }
    }

    var bestLiveRSSI: Int? {
        connectedAirPods.compactMap(\.rssi).max()
    }

    func start() {
        stop()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let snapAny = bridge.snapshot()
        let snap = snapAny as? [String: Any] ?? [:]
        headphoneManagerLoaded = (snap["headphoneManagerLoaded"] as? NSNumber)?.boolValue ?? false
        bluetoothManagerLoaded = (snap["bluetoothManagerLoaded"] as? NSNumber)?.boolValue ?? false
        headphoneManagerInstance = (snap["headphoneManagerInstance"] as? NSNumber)?.boolValue ?? false
        bluetoothManagerInstance = (snap["bluetoothManagerInstance"] as? NSNumber)?.boolValue ?? false

        var next: [ConnectedAirPodsRecord] = []
        let hc = snap["hpmConnected"] as? [[String: Any]] ?? []
        next += hc.enumerated().map { ConnectedAirPodsRecord.hpm($0.element, index: $0.offset, connected: true) }
        let hp = snap["hpmPaired"] as? [[String: Any]] ?? []
        next += hp.enumerated().map { ConnectedAirPodsRecord.hpm($0.element, index: $0.offset + 1000, connected: false) }

        let bc = snap["btmConnected"] as? [[String: Any]] ?? []
        next += bc.enumerated().map { ConnectedAirPodsRecord.btm($0.element, index: $0.offset, connected: true) }
        let bp = snap["btmPaired"] as? [[String: Any]] ?? []
        next += bp.enumerated().map { ConnectedAirPodsRecord.btm($0.element, index: $0.offset + 1000, connected: false) }

        var dedup: [String: ConnectedAirPodsRecord] = [:]
        for record in next {
            let key = "\(record.source)|\(record.id)|\(record.connected)"
            dedup[key] = record
        }
        records = dedup.values.sorted {
            if $0.connected != $1.connected { return $0.connected && !$1.connected }
            if $0.genuineAirPods != $1.genuineAirPods { return $0.genuineAirPods && !$1.genuineAirPods }
            return $0.name < $1.name
        }

        let route = AVAudioSession.sharedInstance().currentRoute
        audioRoutes = route.outputs.map { "\($0.portName) • \($0.portType.rawValue) • \($0.uid)" }

        if !audioRoutes.isEmpty && connectedAirPods.isEmpty {
            status = "iOS audio route sees the headphones, but private paired-device layers returned no AirPods."
        } else if let rssi = bestLiveRSSI {
            status = "Connected AirPods found with live CBDevice RSSI: \(rssi) dBm"
        } else if !connectedAirPods.isEmpty {
            status = "Connected AirPods identity found. No live RSSI is populated yet."
        } else if headphoneManagerInstance || bluetoothManagerInstance {
            status = "Private managers loaded, but no AirPods record was returned."
        } else {
            status = "Private managers could not be instantiated from this SideStore process."
        }

        if JSONSerialization.isValidJSONObject(snap),
           let data = try? JSONSerialization.data(withJSONObject: snap, options: [.prettyPrinted, .sortedKeys]) {
            rawJSON = String(data: data, encoding: .utf8) ?? ""
        } else {
            rawJSON = String(describing: snap)
        }
    }
}
