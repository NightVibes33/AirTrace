import Foundation
import CoreBluetooth
import simd

enum AirPodsModel: UInt16, CaseIterable, Codable, Identifiable {
    case airPods1 = 0x0220
    case airPods2 = 0x0F20
    case airPods3 = 0x1320
    case airPods4 = 0x1920
    case airPods4ANC = 0x1B20
    case airPodsMax = 0x0A20
    case airPodsMaxUSBC = 0x1F20
    case airPodsPro = 0x0E20
    case airPodsPro2 = 0x1420
    case airPodsPro2USBC = 0x2420
    case airPodsPro3 = 0x2720

    var id: UInt16 { rawValue }

    var displayName: String {
        switch self {
        case .airPods1: return "AirPods (1st generation)"
        case .airPods2: return "AirPods (2nd generation)"
        case .airPods3: return "AirPods (3rd generation)"
        case .airPods4: return "AirPods 4"
        case .airPods4ANC: return "AirPods 4 with ANC"
        case .airPodsMax: return "AirPods Max"
        case .airPodsMaxUSBC: return "AirPods Max (USB-C)"
        case .airPodsPro: return "AirPods Pro"
        case .airPodsPro2: return "AirPods Pro (2nd generation)"
        case .airPodsPro2USBC: return "AirPods Pro 2 (USB-C)"
        case .airPodsPro3: return "AirPods Pro 3"
        }
    }

    var symbolName: String {
        switch self {
        case .airPodsMax, .airPodsMaxUSBC: return "airpodsmax"
        case .airPodsPro, .airPodsPro2, .airPodsPro2USBC, .airPodsPro3: return "airpodspro"
        default: return "airpods"
        }
    }
}

struct AirPodsAdvertisement: Equatable {
    let model: AirPodsModel
    let modelCode: UInt16
    let pairingMode: UInt8
    let rssi: Int
    let timestamp: TimeInterval
    let leftBattery: Int?
    let rightBattery: Int?
    let caseBattery: Int?
    let lidOpen: Bool?
    let rawPayload: Data

    static func batteryPercent(nibble: UInt8) -> Int? {
        if nibble == 0x0F { return nil }
        if nibble >= 0x0A { return 100 }
        return Int(nibble) * 10
    }
}

struct DiscoveredAirPods: Identifiable, Equatable {
    let id: UUID
    let peripheralID: UUID
    let advertisement: AirPodsAdvertisement
    let firstSeen: Date
    let lastSeen: Date

    var model: AirPodsModel { advertisement.model }
    var rssi: Int { advertisement.rssi }
}

struct TargetProfile: Codable, Equatable {
    var model: AirPodsModel
    var peripheralID: UUID?
    var referenceRSSIAtOneMeter: Double
    var displayName: String
    var enrolledAt: Date

    static func fresh(from discovered: DiscoveredAirPods) -> TargetProfile {
        TargetProfile(
            model: discovered.model,
            peripheralID: discovered.peripheralID,
            referenceRSSIAtOneMeter: -52,
            displayName: discovered.model.displayName,
            enrolledAt: Date()
        )
    }
}

struct SpatialRadioSample: Identifiable {
    let id = UUID()
    let position: SIMD3<Float>
    let cameraForward: SIMD3<Float>
    let rssi: Double
    let timestamp: TimeInterval
}

struct LocalizationEstimate: Equatable {
    var position: SIMD3<Float>
    var uncertaintyRadius: Float
    var confidence: Float
    var sampleCount: Int

    static let empty = LocalizationEstimate(position: .zero, uncertaintyRadius: 99, confidence: 0, sampleCount: 0)
}

enum SearchMode: String, CaseIterable, Identifiable {
    case guided = "Guided 3D"
    case precision = "Precision"

    var id: String { rawValue }
}

enum SearchPhase: String {
    case idle = "Ready"
    case acquiring = "Acquiring AirPods"
    case mapping = "Mapping signal"
    case converging = "Converging"
    case precision = "Precision region"
    case unavailable = "Signal unavailable"
}

struct SearchRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let model: AirPodsModel
    let sampleCount: Int
    let uncertaintyMeters: Float
    let confidence: Float
    let durationSeconds: TimeInterval
}

struct Particle {
    var position: SIMD3<Float>
    var weight: Double
}

extension SIMD3 where Scalar == Float {
    var length: Float { simd_length(self) }
}
