import Foundation
import SwiftUI
import CoreBluetooth
import ARKit

struct RootView: View {
    @ObservedObject var search: SearchCoordinator

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    HeroHeader()

                    if let target = search.target {
                        DeviceStatusCard(scanner: search.scanner, target: target)

                        NavigationLink(destination: FinderScreen(search: search, mode: .guided)) {
                            ActionCard(title: "Find in 3D", subtitle: "Map the room and collapse the AirPods search region", icon: "viewfinder", primary: true)
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: FinderScreen(search: search, mode: .precision)) {
                            ActionCard(title: "Precision Search", subtitle: "More samples and a tighter localization filter", icon: "scope", primary: true)
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: QuickRadarScreen(scanner: search.scanner, target: target)) {
                            ActionCard(title: "Quick Radar", subtitle: "Hot / cold AirPods signal finder", icon: "dot.radiowaves.left.and.right", primary: false)
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: HistoryView(search: search)) {
                            ActionCard(title: "Search History", subtitle: "Review recent localization sessions", icon: "clock.arrow.circlepath", primary: false)
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: SettingsView(search: search)) {
                            ActionCard(title: "AirPods Setup", subtitle: "Calibration and enrolled device settings", icon: "slider.horizontal.3", primary: false)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        EnrollmentView(search: search)
                    }

                    Text("AirTrace estimates a probable region from radio measurements. Bluetooth RSSI changes with walls, people, reflections and AirPods orientation, so the displayed uncertainty is an estimate rather than exact ranging.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                .padding(18)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .onAppear { search.beginDiscovery() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct HeroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 58, height: 58)
                    Image(systemName: "airpodspro")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                Spacer()
                Text("AIRPODS ONLY")
                    .font(.caption2.bold())
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text("AirTrace")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Spatial AirPods finder")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DeviceStatusCard: View {
    @ObservedObject var scanner: AirPodsScanner
    let target: TargetProfile

    private var match: DiscoveredAirPods? { scanner.bestMatch(for: target) }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: target.model.symbolName)
                .font(.system(size: 31))
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(target.displayName).font(.headline).lineLimit(2)
                HStack(spacing: 7) {
                    Circle().fill(match == nil ? Color.orange : Color.green).frame(width: 8, height: 8)
                    Text(match == nil ? "Waiting for AirPods signal" : "AirPods signal detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let match = match {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(match.rssi)").font(.system(.headline, design: .monospaced))
                    Text("dBm").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct EnrollmentView: View {
    @ObservedObject var search: SearchCoordinator
    @ObservedObject private var scanner: AirPodsScanner

    init(search: SearchCoordinator) {
        self.search = search
        self.scanner = search.scanner
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add your AirPods").font(.title2.bold())
            Text("Open the AirPods case and bring it near this iPhone. AirTrace filters out non-AirPods Bluetooth devices before they reach this screen.")
                .foregroundColor(.secondary)

            bluetoothStatus

            if scanner.candidates.isEmpty {
                VStack(spacing: 13) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .cyan)).scaleEffect(1.2)
                    Text("Scanning for AirPods…").font(.headline)
                    Text("Keep the case open and close to the phone.").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(scanner.candidates) { candidate in
                    Button(action: { search.enroll(candidate) }) {
                        HStack(spacing: 13) {
                            Image(systemName: candidate.model.symbolName).font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.model.displayName).font(.headline)
                                Text("\(candidate.rssi) dBm • tap to use these AirPods")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onAppear { scanner.start() }
    }

    @ViewBuilder private var bluetoothStatus: some View {
        switch scanner.bluetoothState {
        case .poweredOn:
            EmptyView()
        case .unauthorized:
            Label("Bluetooth permission is required.", systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
        case .poweredOff:
            Label("Turn Bluetooth on to find AirPods.", systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
        default:
            Label("Preparing Bluetooth…", systemImage: "hourglass").foregroundColor(.secondary)
        }
    }
}

struct FinderScreen: View {
    @ObservedObject var search: SearchCoordinator
    let mode: SearchMode
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            ARFinderView(search: search).edgesIgnoringSafeArea(.all)
            LinearGradient(colors: [Color.black.opacity(0.65), Color.clear, Color.black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                topBar
                Spacer()
                if let direction = search.targetDirectionText() { directionBadge(direction) }
                searchPanel
            }
            .padding(16)
        }
        .navigationBarHidden(true)
        .onAppear { search.startSearch(mode: mode) }
        .onDisappear { search.stopSearch() }
    }

    private var topBar: some View {
        HStack {
            Button(action: {
                search.stopSearch()
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                    .background(.ultraThinMaterial).clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(mode.rawValue.uppercased()).font(.caption.bold()).foregroundColor(.cyan)
                Text(search.phase.rawValue).font(.headline)
            }
            .padding(.horizontal, 15).padding(.vertical, 9)
            .background(.ultraThinMaterial).clipShape(Capsule())
            Spacer()
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 44, height: 44)
                if let rssi = search.latestRSSI {
                    Text("\(abs(rssi))").font(.caption.bold().monospacedDigit())
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                }
            }
        }
    }

    private func directionBadge(_ direction: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: directionIcon(direction)).font(.system(size: 30, weight: .bold))
            Text(direction).font(.title3.bold())
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(Color.black.opacity(0.60)).clipShape(Capsule())
        .overlay(Capsule().stroke(Color.cyan.opacity(0.55), lineWidth: 1))
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Estimated region").font(.caption).foregroundColor(.secondary)
                    Text(search.estimate.sampleCount < 4 ? "Building map…" : String(format: "± %.1f m", search.estimate.uncertaintyRadius))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Confidence").font(.caption).foregroundColor(.secondary)
                    Text("\(Int(search.estimate.confidence * 100))%")
                        .font(.title3.bold().monospacedDigit()).foregroundColor(.cyan)
                }
            }
            ProgressView(value: Double(search.estimate.confidence)).progressViewStyle(LinearProgressViewStyle(tint: .cyan))
            Text(search.guidance).font(.headline)
            HStack(spacing: 14) {
                Label("\(search.sampleCount) samples", systemImage: "waveform.path.ecg")
                Label(String(format: "%.1f m path", search.trajectorySpan), systemImage: "figure.walk")
                if let surface = search.surfaceHint { Label(surface, systemImage: "cube.transparent") }
            }
            .font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func directionIcon(_ direction: String) -> String {
        switch direction {
        case "LEFT": return "arrow.left"
        case "RIGHT": return "arrow.right"
        case "BEHIND YOU": return "arrow.uturn.backward"
        default: return "arrow.up"
        }
    }
}

struct QuickRadarScreen: View {
    @ObservedObject var scanner: AirPodsScanner
    let target: TargetProfile

    private var rssi: Int? { scanner.rssi(for: target) }
    private var normalized: CGFloat {
        guard let value = rssi else { return 0 }
        return CGFloat(min(1, max(0, (Double(value) + 95) / 55)))
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: target.model.symbolName)
                .font(.system(size: 64)).foregroundColor(.cyan).padding(28)
                .background(Color.cyan.opacity(0.12)).clipShape(Circle())
            Text(target.displayName).font(.title2.bold())
            Text(radarLabel).font(.system(size: 34, weight: .bold, design: .rounded))
            if let value = rssi {
                Text("\(value) dBm").font(.title3.monospacedDigit()).foregroundColor(.secondary)
            } else {
                Text("Waiting for AirPods signal").foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(Color.cyan).frame(width: geo.size.width * normalized)
                }
            }
            .frame(height: 16)
            Text("Move the iPhone slowly. A stronger signal means you are probably closer, but RSSI is not an exact distance measurement.")
                .font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle("Quick Radar")
        .onAppear { scanner.start() }
    }

    private var radarLabel: String {
        guard let value = rssi else { return "Searching…" }
        if value >= -45 { return "Very close" }
        if value >= -58 { return "Close" }
        if value >= -70 { return "Nearby" }
        if value >= -82 { return "Far" }
        return "Very far"
    }
}

struct CalibrationView: View {
    @ObservedObject var search: SearchCoordinator
    @ObservedObject private var scanner: AirPodsScanner
    @State private var calibrating = false
    @State private var progress: Double = 0
    @State private var resultText: String?

    init(search: SearchCoordinator) {
        self.search = search
        self.scanner = search.scanner
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("1-meter calibration").font(.title2.bold())
            Text("Place the AirPods about 1 meter from the iPhone, open the case if necessary, and keep both still. AirTrace samples the live signal for five seconds.")
                .foregroundColor(.secondary)
            if let target = search.target {
                HStack {
                    Text("Current reference")
                    Spacer()
                    Text(String(format: "%.0f dBm", target.referenceRSSIAtOneMeter)).monospacedDigit()
                }
                ProgressView(value: progress).progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                Button(action: { runCalibration(target: target) }) {
                    Label(calibrating ? "Sampling…" : "Calibrate now", systemImage: "ruler")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(BorderedProminentButtonStyle()).tint(.cyan).disabled(calibrating)
                if let resultText = resultText {
                    Text(resultText).font(.footnote).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle("Calibration")
        .onAppear { scanner.start() }
    }

    private func runCalibration(target: TargetProfile) {
        calibrating = true
        progress = 0
        resultText = nil
        Task { @MainActor in
            var values: [Int] = []
            for index in 0..<25 {
                if let value = scanner.rssi(for: target), value != 127 { values.append(value) }
                progress = Double(index + 1) / 25.0
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            calibrating = false
            guard !values.isEmpty else {
                resultText = "No AirPods packets were received. Open the case and try again."
                return
            }
            values.sort()
            let median = values[values.count / 2]
            search.updateReferenceRSSI(Double(median))
            resultText = "Saved \(median) dBm as the 1-meter reference from \(values.count) samples."
        }
    }
}

struct SettingsView: View {
    @ObservedObject var search: SearchCoordinator
    @State private var confirmForget = false

    var body: some View {
        List {
            if let target = search.target {
                Section(header: Text("Your AirPods")) {
                    HStack {
                        Label(target.displayName, systemImage: target.model.symbolName)
                        Spacer()
                        Text(String(format: "0x%04X", target.model.rawValue)).font(.caption.monospaced()).foregroundColor(.secondary)
                    }
                    NavigationLink(destination: CalibrationView(search: search)) {
                        Text("Calibrate signal model")
                    }
                }
                Section(header: Text("Localization")) {
                    Text("Guided 3D uses ARKit camera pose plus repeated AirPods RSSI observations. Precision mode increases particle count and sample density.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section {
                    Button(role: .destructive, action: { confirmForget = true }) { Text("Forget enrolled AirPods") }
                }
            }
        }
        .navigationTitle("AirPods Setup")
        .alert("Forget these AirPods?", isPresented: $confirmForget) {
            Button("Cancel", role: .cancel) { }
            Button("Forget", role: .destructive) { search.forgetTarget() }
        } message: {
            Text("You can enroll them again by opening the case near the iPhone.")
        }
    }
}

struct HistoryView: View {
    @ObservedObject var search: SearchCoordinator

    var body: some View {
        List {
            if search.history.isEmpty {
                Text("No completed search sessions yet.").foregroundColor(.secondary)
            } else {
                ForEach(search.history) { record in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(record.model.displayName).font(.headline)
                            Spacer()
                            Text(record.date, style: .date).font(.caption).foregroundColor(.secondary)
                        }
                        HStack(spacing: 14) {
                            Text("±\(String(format: "%.1f", record.uncertaintyMeters)) m")
                            Text("\(Int(record.confidence * 100))%")
                            Text("\(record.sampleCount) samples")
                            Text("\(Int(record.durationSeconds))s")
                        }
                        .font(.caption.monospacedDigit()).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Search History")
    }
}

struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let primary: Bool

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: primary ? 27 : 22, weight: .semibold))
                .foregroundColor(primary ? .black : .cyan)
                .frame(width: 54, height: 54)
                .background(primary ? Color.cyan : Color.cyan.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(primary ? .title3.bold() : .headline)
                Text(subtitle).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.white.opacity(primary ? 0.07 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
