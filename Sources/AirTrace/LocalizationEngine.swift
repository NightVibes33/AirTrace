import Foundation
import simd

final class LocalizationEngine {
    private(set) var samples: [SpatialRadioSample] = []
    private var particles: [Particle] = []
    private var referenceRSSI: Double = -52
    private var pathLossExponent: Double = 2.2
    private var mode: SearchMode = .guided

    func reset(referenceRSSI: Double, mode: SearchMode) {
        samples.removeAll(keepingCapacity: true)
        particles.removeAll(keepingCapacity: true)
        self.referenceRSSI = referenceRSSI
        self.mode = mode
        self.pathLossExponent = mode == .precision ? 2.15 : 2.25
    }

    func ingest(_ sample: SpatialRadioSample) -> LocalizationEstimate {
        samples.append(sample)
        if particles.isEmpty {
            seedParticles(around: sample.position)
        }

        let sigmaDB: Double = mode == .precision ? 6.5 : 8.0
        let sigma2 = sigmaDB * sigmaDB
        var totalWeight = 0.0

        for i in particles.indices {
            let distance = max(0.18, Double(simd_distance(particles[i].position, sample.position)))
            let expectedRSSI = referenceRSSI - 10.0 * pathLossExponent * log10(distance)
            let error = sample.rssi - expectedRSSI
            let likelihood = exp(-0.5 * error * error / sigma2)
            particles[i].weight = max(1e-18, particles[i].weight * max(1e-8, likelihood))
            totalWeight += particles[i].weight
        }

        normalize(totalWeight: totalWeight)
        let estimate = estimatePosition()
        if effectiveSampleSize() < Double(particles.count) * 0.42 {
            systematicResample()
        }
        return estimate
    }

    func estimatedDistance(forRSSI rssi: Double) -> Double {
        pow(10.0, (referenceRSSI - rssi) / (10.0 * pathLossExponent))
    }

    func trajectorySpan() -> Float {
        guard let first = samples.first else { return 0 }
        var maxDistance: Float = 0
        for sample in samples {
            maxDistance = max(maxDistance, simd_distance(first.position, sample.position))
        }
        return maxDistance
    }

    private func seedParticles(around center: SIMD3<Float>) {
        let count = mode == .precision ? 14_000 : 8_000
        particles.reserveCapacity(count)
        let radius: Float = mode == .precision ? 5.0 : 6.0
        let weight = 1.0 / Double(count)

        for _ in 0..<count {
            let x = Float.random(in: -radius...radius)
            let z = Float.random(in: -radius...radius)
            let y = Float.random(in: -2.0...1.8)
            particles.append(Particle(position: center + SIMD3<Float>(x, y, z), weight: weight))
        }
    }

    private func normalize(totalWeight: Double) {
        guard totalWeight.isFinite, totalWeight > 1e-20 else {
            let equal = 1.0 / Double(max(1, particles.count))
            for i in particles.indices { particles[i].weight = equal }
            return
        }
        for i in particles.indices { particles[i].weight /= totalWeight }
    }

    private func estimatePosition() -> LocalizationEstimate {
        guard !particles.isEmpty else { return .empty }

        var mean = SIMD3<Double>(repeating: 0)
        for particle in particles {
            mean += SIMD3<Double>(Double(particle.position.x), Double(particle.position.y), Double(particle.position.z)) * particle.weight
        }
        let meanF = SIMD3<Float>(Float(mean.x), Float(mean.y), Float(mean.z))

        var variance = 0.0
        for particle in particles {
            let d = Double(simd_distance(particle.position, meanF))
            variance += d * d * particle.weight
        }

        // A conservative probability radius. It is explicitly an uncertainty estimate,
        // not a claim of centimeter-level ranging accuracy.
        let uncertainty = Float(min(9.9, max(0.15, sqrt(variance) * 1.65)))
        let span = trajectorySpan()
        let sampleScore = min(1.0, Float(samples.count) / (mode == .precision ? 80.0 : 45.0))
        let geometryScore = min(1.0, span / 2.2)
        let precisionScore = max(0, 1.0 - min(1.0, uncertainty / 4.0))
        let confidence = min(0.99, max(0.02, sampleScore * 0.30 + geometryScore * 0.30 + precisionScore * 0.40))

        return LocalizationEstimate(
            position: meanF,
            uncertaintyRadius: uncertainty,
            confidence: confidence,
            sampleCount: samples.count
        )
    }

    private func effectiveSampleSize() -> Double {
        let sumSquares = particles.reduce(0.0) { $0 + $1.weight * $1.weight }
        return sumSquares > 0 ? 1.0 / sumSquares : 0
    }

    private func systematicResample() {
        guard !particles.isEmpty else { return }
        let n = particles.count
        let step = 1.0 / Double(n)
        let start = Double.random(in: 0..<step)
        var cumulative = particles[0].weight
        var index = 0
        var output: [Particle] = []
        output.reserveCapacity(n)

        for m in 0..<n {
            let target = start + Double(m) * step
            while target > cumulative && index < n - 1 {
                index += 1
                cumulative += particles[index].weight
            }
            let source = particles[index].position
            let jitter: Float = mode == .precision ? 0.045 : 0.08
            let p = source + SIMD3<Float>(
                Float.random(in: -jitter...jitter),
                Float.random(in: -jitter...jitter),
                Float.random(in: -jitter...jitter)
            )
            output.append(Particle(position: p, weight: step))
        }
        particles = output
    }
}
