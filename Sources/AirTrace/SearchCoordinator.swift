import Foundation
import Combine
import simd

final class SearchCoordinator: ObservableObject {
    let scanner: AirPodsScanner

    @Published private(set) var target: TargetProfile?
    @Published private(set) var estimate: LocalizationEstimate = .empty
    @Published private(set) var phase: SearchPhase = .idle
    @Published private(set) var guidance = "Start a search and walk around the room."
    @Published private(set) var latestRSSI: Int?
    @Published private(set) var sampleCount = 0
    @Published private(set) var trajectorySpan: Float = 0
    @Published var surfaceHint: String?
    @Published private(set) var searchActive = false
    @Published private(set) var history: [SearchRecord] = []

    private let engine = LocalizationEngine()
    private let localizationQueue = DispatchQueue(label: "AirTrace.Localization", qos: .userInitiated)
    private var latestTransform: simd_float4x4?
    private var mode: SearchMode = .guided
    private var startedAt: Date?
    private var lastAcceptedSampleAt: TimeInterval = 0

    private let targetKey = "AirTrace.TargetProfile.v1"
    private let historyKey = "AirTrace.SearchHistory.v1"

    init(scanner: AirPodsScanner = AirPodsScanner()) {
        self.scanner = scanner
        loadPersistence()
        scanner.onAirPodsObservation = { [weak self] observation in
            self?.handle(observation)
        }
    }

    func beginDiscovery() {
        scanner.start()
    }

    func enroll(_ discovered: DiscoveredAirPods) {
        let profile = TargetProfile.fresh(from: discovered)
        target = profile
        saveTarget(profile)
    }

    func forgetTarget() {
        stopSearch(saveRecord: false)
        target = nil
        UserDefaults.standard.removeObject(forKey: targetKey)
    }

    func updateReferenceRSSI(_ value: Double) {
        guard var profile = target else { return }
        profile.referenceRSSIAtOneMeter = min(-25, max(-85, value))
        target = profile
        saveTarget(profile)
    }

    func startSearch(mode: SearchMode) {
        guard let target else {
            phase = .unavailable
            guidance = "Enroll your AirPods first."
            return
        }
        self.mode = mode
        estimate = .empty
        sampleCount = 0
        trajectorySpan = 0
        surfaceHint = nil
        latestRSSI = nil
        lastAcceptedSampleAt = 0
        startedAt = Date()
        searchActive = true
        phase = .acquiring
        guidance = "Walk slowly until AirTrace locks onto your AirPods signal."
        engine.reset(referenceRSSI: target.referenceRSSIAtOneMeter, mode: mode)
        scanner.start()
    }

    func stopSearch(saveRecord: Bool = true) {
        if saveRecord, searchActive, let target, sampleCount >= 5, let startedAt {
            let record = SearchRecord(
                id: UUID(),
                date: Date(),
                model: target.model,
                sampleCount: sampleCount,
                uncertaintyMeters: estimate.uncertaintyRadius,
                confidence: estimate.confidence,
                durationSeconds: Date().timeIntervalSince(startedAt)
            )
            history.insert(record, at: 0)
            history = Array(history.prefix(20))
            saveHistory()
        }
        searchActive = false
        phase = .idle
        guidance = "Search stopped."
        startedAt = nil
    }

    func updateCameraTransform(_ transform: simd_float4x4) {
        latestTransform = transform
    }

    func targetDirectionText() -> String? {
        guard estimate.sampleCount >= 8, estimate.confidence > 0.20, let transform = latestTransform else { return nil }
        let camera = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let forward = simd_normalize(-SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
        let right = simd_normalize(SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z))
        let toTarget = simd_normalize(estimate.position - camera)
        let f = simd_dot(forward, toTarget)
        let r = simd_dot(right, toTarget)
        if f > 0.72 { return "AHEAD" }
        if f < -0.55 { return "BEHIND YOU" }
        if r > 0.30 { return "RIGHT" }
        if r < -0.30 { return "LEFT" }
        return "NEARBY"
    }

    private func handle(_ observation: DiscoveredAirPods) {
        guard let target, observation.model == target.model else { return }

        if let savedID = target.peripheralID {
            if observation.peripheralID != savedID {
                // Identifiers can change, so fall back only if the saved one is no longer
                // visible and this is currently the strongest same-model AirPods candidate.
                if scanner.candidates.contains(where: { $0.peripheralID == savedID }) { return }
                guard scanner.bestMatch(for: target)?.peripheralID == observation.peripheralID else { return }
            }
        } else {
            guard scanner.bestMatch(for: target)?.peripheralID == observation.peripheralID else { return }
        }

        latestRSSI = observation.rssi
        guard searchActive, let transform = latestTransform else { return }

        let now = observation.advertisement.timestamp
        let minInterval: TimeInterval = mode == .precision ? 0.08 : 0.14
        guard now - lastAcceptedSampleAt >= minInterval else { return }
        lastAcceptedSampleAt = now

        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let forward = simd_normalize(-SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
        let sample = SpatialRadioSample(
            position: position,
            cameraForward: forward,
            rssi: Double(observation.rssi),
            timestamp: now
        )

        let engine = self.engine
        localizationQueue.async { [weak self] in
            guard let self else { return }
            let estimate = engine.ingest(sample)
            let span = engine.trajectorySpan()
            DispatchQueue.main.async {
                guard self.searchActive else { return }
                self.estimate = estimate
                self.sampleCount = estimate.sampleCount
                self.trajectorySpan = span
                self.phase = self.phaseFor(estimate: estimate, span: span)
                self.guidance = self.guidanceFor(estimate: estimate, span: span)
            }
        }
    }

    private func phaseFor(estimate: LocalizationEstimate, span: Float) -> SearchPhase {
        if estimate.sampleCount < 5 { return .acquiring }
        if span < 0.7 { return .mapping }
        if estimate.uncertaintyRadius <= 0.65 && estimate.confidence >= 0.72 { return .precision }
        return .converging
    }

    private func guidanceFor(estimate: LocalizationEstimate, span: Float) -> String {
        if estimate.sampleCount < 8 {
            return "Keep walking slowly. Collecting AirPods signal samples…"
        }
        if span < 0.8 {
            return "Move about 4 ft sideways to create another measurement angle."
        }
        if span < 1.6 {
            return "Move to the opposite side of the room while keeping the phone upright."
        }
        if estimate.uncertaintyRadius > 2.0 {
            return "Circle the highlighted region. More angles will collapse the search area."
        }
        if estimate.uncertaintyRadius > 0.9 {
            return "Take another angle around the glowing region."
        }
        if let surfaceHint, !surfaceHint.isEmpty {
            return "Search around the \(surfaceHint.lowercased()) inside the highlighted region."
        }
        return "Search inside the glowing region. Continue moving for a tighter lock."
    }

    private func loadPersistence() {
        if let data = UserDefaults.standard.data(forKey: targetKey),
           let decoded = try? JSONDecoder().decode(TargetProfile.self, from: data) {
            target = decoded
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([SearchRecord].self, from: data) {
            history = decoded
        }
    }

    private func saveTarget(_ target: TargetProfile) {
        if let data = try? JSONEncoder().encode(target) {
            UserDefaults.standard.set(data, forKey: targetKey)
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
}
