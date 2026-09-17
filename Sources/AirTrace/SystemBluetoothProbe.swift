import Foundation
import Combine

struct SystemBluetoothDevice: Identifiable {
    let id: String
    let identifier: String
    let name: String?
    let model: String?
    let productName: String?
    let rssi: Int?
    let productID: UInt64?
    let proximityPairingProductID: UInt64?
    let objectDiscoveryProductID: UInt64?
    let findMyCaseIdentifier: String?
    let findMyGroupIdentifier: String?
    let appleManufacturerHex: String?
    let advertisementHex: String?
    let runtimeClass: String
    let rawDescription: String
    let raw: [String: Any]
    let seenAt: Date

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let productName, !productName.isEmpty { return productName }
        if let model, !model.isEmpty { return model }
        return "System Bluetooth device"
    }

    var airPodsEvidence: [String] {
        var evidence: [String] = []
        let text = [name, model, productName, rawDescription]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        if text.contains("airpods") || text.contains("air pods") {
            evidence.append("AirPods name/model")
        }
        if let findMyCaseIdentifier, !findMyCaseIdentifier.isEmpty {
            evidence.append("Find My case ID")
        }
        if let proximityPairingProductID, proximityPairingProductID != 0 {
            evidence.append("Proximity-pairing product")
        }
        if let manufacturer = appleManufacturerHex, !manufacturer.isEmpty {
            evidence.append("Apple manufacturer payload")
        }
        return evidence
    }

    var looksLikeAirPods: Bool {
        let text = [name, model, productName, rawDescription]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        return text.contains("airpods") || text.contains("air pods") ||
            (findMyCaseIdentifier?.isEmpty == false)
    }

    static func make(from dictionary: [String: Any]) -> SystemBluetoothDevice {
        func string(_ key: String) -> String? {
            if let value = dictionary[key] as? String, !value.isEmpty { return value }
            return nil
        }
        func uint(_ key: String) -> UInt64? {
            if let value = dictionary[key] as? NSNumber { return value.uint64Value }
            if let value = dictionary[key] as? UInt64 { return value }
            if let value = dictionary[key] as? Int { return UInt64(max(0, value)) }
            return nil
        }
        func int(_ key: String) -> Int? {
            if let value = dictionary[key] as? NSNumber { return value.intValue }
            if let value = dictionary[key] as? Int { return value }
            return nil
        }

        let identifier = string("identifier")
            ?? string("btAddress")
            ?? string("bleAddressHex")
            ?? UUID().uuidString
        let timestamp = (dictionary["seenAt"] as? NSNumber)?.doubleValue
            ?? Date().timeIntervalSince1970

        return SystemBluetoothDevice(
            id: identifier,
            identifier: identifier,
            name: string("name") ?? string("leAdvName"),
            model: string("model") ?? string("modelUser"),
            productName: string("productName"),
            rssi: int("bleRSSI"),
            productID: uint("productID"),
            proximityPairingProductID: uint("proximityPairingProductID"),
            objectDiscoveryProductID: uint("objectDiscoveryProductID"),
            findMyCaseIdentifier: string("findMyCaseIdentifier"),
            findMyGroupIdentifier: string("findMyGroupIdentifier"),
            appleManufacturerHex: string("appleManufacturerHex"),
            advertisementHex: string("advertisementHex"),
            runtimeClass: string("runtimeClass") ?? "unknown",
            rawDescription: string("rawDescription") ?? "",
            raw: dictionary,
            seenAt: Date(timeIntervalSince1970: timestamp)
        )
    }
}

@MainActor
final class SystemBluetoothProbeModel: ObservableObject {
    @Published private(set) var status = "Not started"
    @Published private(set) var devices: [SystemBluetoothDevice] = []
    @Published private(set) var available = false
    @Published private(set) var active = false
    @Published private(set) var eventCount = 0

    private let bridge = ATPrivateBluetoothProbe()

    init() {
        available = bridge.isAvailable
        bridge.statusHandler = { [weak self] status in
            guard let self else { return }
            self.status = status
            self.active = self.bridge.isActive
        }
        bridge.deviceHandler = { [weak self] payload in
            guard let self else { return }
            let dictionary = payload as? [String: Any] ?? [:]
            let device = SystemBluetoothDevice.make(from: dictionary)
            self.eventCount += 1
            if let index = self.devices.firstIndex(where: { $0.id == device.id }) {
                self.devices[index] = device
            } else {
                self.devices.append(device)
            }
            self.devices.sort {
                if $0.looksLikeAirPods != $1.looksLikeAirPods {
                    return $0.looksLikeAirPods && !$1.looksLikeAirPods
                }
                return ($0.rssi ?? -127) > ($1.rssi ?? -127)
            }
            self.active = self.bridge.isActive
        }
    }

    var airPodsCandidates: [SystemBluetoothDevice] {
        devices.filter(\.looksLikeAirPods)
    }

    func start() {
        devices.removeAll()
        eventCount = 0
        available = bridge.isAvailable
        status = available ? "Starting Apple FindNearbyRemote discovery…" : "CBDiscovery runtime class unavailable"
        bridge.start()
        active = bridge.isActive
    }

    func stop() {
        bridge.stop()
        active = false
        status = "Stopped"
    }
}
