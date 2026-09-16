import SwiftUI
import ARKit
import SceneKit
import simd

struct ARFinderView: UIViewRepresentable {
    @ObservedObject var search: SearchCoordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(search: search)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene()
        view.session.delegate = context.coordinator
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.antialiasingMode = .multisampling4X

        guard ARWorldTrackingConfiguration.isSupported else { return view }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.search = search
        context.coordinator.updateEstimateNode(in: uiView, estimate: search.estimate)
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSessionDelegate, ARSCNViewDelegate {
        var search: SearchCoordinator
        private let estimateNode = SCNNode()
        private var lastHint: String?

        init(search: SearchCoordinator) {
            self.search = search
            super.init()
            estimateNode.name = "AirTraceEstimate"
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let transform = frame.camera.transform
            DispatchQueue.main.async { [weak self] in
                self?.search.updateCameraTransform(transform)
            }
        }

        func updateEstimateNode(in view: ARSCNView, estimate: LocalizationEstimate) {
            guard estimate.sampleCount >= 4 else {
                estimateNode.removeFromParentNode()
                return
            }

            if estimateNode.parent == nil {
                view.scene.rootNode.addChildNode(estimateNode)
            }

            let radius = CGFloat(min(1.15, max(0.13, estimate.uncertaintyRadius * 0.36)))
            let sphere = SCNSphere(radius: radius)
            sphere.segmentCount = 48
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemCyan
            material.emission.contents = UIColor.systemBlue
            material.transparency = CGFloat(0.22 + min(0.38, estimate.confidence * 0.38))
            material.isDoubleSided = true
            sphere.materials = [material]
            estimateNode.geometry = sphere
            estimateNode.position = SCNVector3(estimate.position.x, estimate.position.y, estimate.position.z)

            let scalePulse = SCNAction.sequence([
                .scale(to: 1.07, duration: 0.55),
                .scale(to: 0.96, duration: 0.55)
            ])
            if estimateNode.action(forKey: "pulse") == nil {
                estimateNode.runAction(.repeatForever(scalePulse), forKey: "pulse")
            }

            if let hint = nearestSurfaceHint(frame: view.session.currentFrame, target: estimate.position), hint != lastHint {
                lastHint = hint
                DispatchQueue.main.async { [weak self] in
                    self?.search.surfaceHint = hint
                }
            }
        }

        private func nearestSurfaceHint(frame: ARFrame?, target: SIMD3<Float>) -> String? {
            guard let frame else { return nil }
            var best: (distance: Float, name: String)?

            for case let plane as ARPlaneAnchor in frame.anchors {
                let center = SIMD4<Float>(plane.center.x, plane.center.y, plane.center.z, 1)
                let world = plane.transform * center
                let p = SIMD3<Float>(world.x, world.y, world.z)
                let distance = simd_distance(p, target)
                guard distance < 1.25 else { continue }

                let name: String
                switch plane.classification {
                case .floor: name = "Floor"
                case .wall: name = "Wall"
                case .ceiling: name = "Ceiling"
                case .table: name = "Table"
                case .seat: name = "Seat / couch"
                case .door: name = "Door"
                case .window: name = "Window"
                default: name = plane.alignment == .horizontal ? "Horizontal surface" : "Vertical surface"
                }

                if best == nil || distance < best!.distance {
                    best = (distance, name)
                }
            }
            return best?.name
        }
    }
}
