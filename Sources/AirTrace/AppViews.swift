import SwiftUI
import CoreBluetooth
import ARKit

struct RootView: View {
    @ObservedObject var search: SearchCoordinator

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    HeroHeader()

                    if let target = search.target {
                        DeviceStatusCard(scanner: search.scanner, target: target)

                        NavigationLink(destination: FinderScreen(search: search, mode: .guided)) {
                            PrimaryActionCard(
                                title: "Find in 3D",
                                subtitle: "Map the room and collapse the AirPods search region",
                                systemImage: "viewfinder"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: FinderScreen(search: search, mode: .precision)) {
                            PrimaryActionCard(
                                title: "Precision Search",
                                subtitle: "More samples, tighter filtering, longer guided scan",
                                systemImage: "scope"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: QuickRadarScreen(scanner: search.scanner, target: target)) {
                            SecondaryActionCard(
                                title: "Quick Radar",
                                subtitle: "Hot / cold AirPods signal finder",
                                systemImage: "dot.radiowaves.left.and.right"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: HistoryView(search: search)) {
                            SecondaryActionCard(
                                title: "Search History",
                                subtitle: "Review recent localization sessions",
                                systemImage: "clock.arrow.circlepath"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: SettingsView(search: search)) {
                            SecondaryActionCard(
                                title: "AirPods Setup",
                                subtitle: "Calibration and enrolled device settings",
                                systemImage: "slider.horizontal.3"
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        EnrollmentView(search: search)
                    }

                    TechnicalFootnote()
                }
                .padding(18)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear { search.beginDiscovery() }
        }
        .navigationViewStyle(.stack)
    }
}

struct HeroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.cyan.opacity(0.16))
                        .frame(width: 58, height: 58)
                    Image(systemName: "airpodspro")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
                Spacer()
                Text("AIRPODS ONLY")
                    .font(.caption2.bold())
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.cyan.opacity(0.12), in: Capsule())
            }

            Text("AirTrace")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Spatial AirPods finder")
                .font(.headline)
                .foregroundStyle(.secondary)
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
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text(target.displayName)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 7) {
                    Circle()
                        .fill(match == nil ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(match == nil ? "Waiting for AirPods signal" : "AirPods signal detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let match {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(match.rssi)")
                        .font(.system(.headline, design: .monospaced))
                    Text("dBm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08)))
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
            Text("Add your AirPods")
                .font(.title2.bold())
            Text("Open the AirPods case and bring it near this iPhone. AirTrace discards non-AirPods Bluetooth devices before they reach this screen.")
                .foregroundStyle(.secondary)

            bluetoothStatus

            if scanner.candidates.isEmpty {
                VStack(spacing: 13) {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(1.2)
                    Text("Scanning for AirPods…")
                        .font(.headline)
                    Text("Keep the case open and close to the phone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(scanner.candidates) { candidate in
                    Button {
                        search.enroll(candidate)
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: candidate.model.symbolName)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.model.displayName)
                                    .font(.headline)
                                Text("\(candidate.rssi) dBm • tap to use these AirPods")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24))
        .onAppear { scanner.start() }
    }

    @ViewBuilder
    private var bluetoothStatus: some View {
        switch scanner.bluetoothState {
        case .poweredOn:
            EmptyView()
        case .unauthorized:
            Label("Bluetooth permission is required.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .poweredOff:
            Label("Turn Bluetooth on to find AirPods.", systemImage: "bluetooth.slash")
                .foregroundStyle(.orange)
        default:
            Label("Preparing Bluetooth…", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        }
    }
}

struct FinderScreen: View {
    @ObservedObject var search: SearchCoordinator
    let mode: SearchMode
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            ARFinderView(search: search)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.68), .clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                topBar
                Spacer()
                directionBadge
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
            Button {
                search.stopSearch()
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(mode.rawValue.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
                Text(search.phase.rawValue)
                    .font(.headline)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                if let rssi = search.latestRSSI {
                    Text("\(abs(rssi))")
                        .font(.caption.bold().monospacedDigit())
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                }
            }
        }
    }

    @ViewBuilder
    private var directionBadge: some View {
        if let direction = search.targetDirectionText() {
            VStack(spacing: 4) {
                Image(systemName: directionIcon(direction))
                    .font(.system(size: 30, weight: .bold))
                Text(direction)
                    .font(.title3.bold())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.black.opacity(0.58), in: Capsule())
            .overlay(Capsule().stroke(.cyan.opacity(0.55)))
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Estimated region")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(search.estimate.sampleCount < 4 ? "Building map…" : String(format: "± %.1f m", search.estimate.uncertaintyRadius))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(search.estimate.confidence * 100))%")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.cyan)
                }
            }

            ProgressView(value: Double(search.estimate.confidence))
                .tint(.cyan)

            Text(search.guidance)
                .font(.headline)

            HStack(spacing: 16) {
                Label("\(search.sampleCount) samples", systemImage: "waveform.path.ecg")
                Label(String(format: "%.1f m path", search.trajectorySpan), systemImage: "figure.walk")
                if let surface = search.surfaceHint {
                    Label(surface, systemImage: "cube.transparent")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.10)))
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
    private var normalized: Double {
        guard let rssi else { return 0 }
        return min(1, max(0, (Double(rssi) + 95) / 55))
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: target.model.symbolName)
                .font(.system(size: 64))
                .foregroundStyle(.cyan)
                .padding(28)
                .background(.cyan.opacity(0.12), in: Circle())

            Text(target.displayName)
                .font(.title2.bold())

            Text(radarLabel)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            if let rssi {
                Text("\(rssi) dBm")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("Waiting for AirPods signal")
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule().fill(.cyan)
                        .frame(width: geo.size.width * normalized)
                }
            }
            .frame(height: 16)

            Text("Move the iPhone slowly. A stronger signal means you are probably closer, but RSSI is not an exact distance measurement.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(24)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Quick Radar")
        .onAppear { scanner.start() }
    }

    private var radarLabel: String {
        guard let rssi else { return "Searching…" }
        if rssi >= -45 { return "Very close" }
        if rssi >= -58 { return "Close" }
        if rssi >= -70 { return "Nearby" }
        if rssi >= -82 { return "Far" }
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
            Text("1-meter calibration")
                .font(.title2.bold())
            Text("Place the AirPods about 1 meter from the iPhone, open the case if necessary, and keep both still. AirTrace will sample the live signal for five seconds.")
                .foregroundStyle(.secondary)

            if let target = search.target {
                HStack {
                    Text("Current reference")
                    Spacer()
                    Text(String(format: "%.0f dBm", target.referenceRSSIAtOneMeter))
                        .monospacedDigit()
                }

                ProgressView(value: progress)
                    .tint(.cyan)

                Button {
                    runCalibration(target: target)
                } label: {
                    Label(calibrating ? "Sampling…" : "Calibrate now", systemImage: "ruler")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(calibrating)

                if let resultText {
                    Text(resultText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .background(Color.black.ignoresSafeArea())
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
                if let value = scanner.rssi(for: target), value != 127 {
                    values.append(value)
                }
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
            resultText = "Saved \(median) dBm as this AirPods set's 1-meter reference (\(values.count) samples)."
        }
    }
}

struct SettingsView: View {
    @ObservedObject var search: SearchCoordinator
    @State private var confirmForget = false

    var body: some View {
        List {
            if let target = search.target {
                Section("Your AirPods") {
                    HStack {
                        Label(target.displayName, systemImage: target.model.symbolName)
                        Spacer()
                        Text(String(format: "0x%04X", target.model.rawValue))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("Calibrate signal model") {
                        CalibrationView(search: search)
                    }
                }

                Section("Localization") {
                    Text("Guided 3D uses ARKit camera pose plus repeated AirPods RSSI observations. Precision mode increases particle count and sample density.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        confirmForget = true
                    } label: {
                        Text("Forget enrolled AirPods")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
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
                Text("No completed search sessions yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(search.history) { record in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(record.model.displayName)
                                .font(.headline)
                            Spacer()
                            Text(record.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 14) {
                            Text("±\(String(format: "%.1f", record.uncertaintyMeters)) m")
                            Text("\(Int(record.confidence * 100))%")
                            Text("\(record.sampleCount) samples")
                            Text("\(Int(record.durationSeconds))s")
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Search History")
    }
}

struct PrimaryActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: systemImage)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 54, height: 54)
                .background(.cyan, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.cyan.opacity(0.22)))
    }
}

struct SecondaryActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 44, height: 44)
                .background(.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct TechnicalFootnote: View {
    var body: some View {
        Text("AirTrace estimates a probable region from radio measurements. Bluetooth RSSI is affected by walls, bodies, reflections and AirPods orientation, so the displayed uncertainty is an estimate rather than exact ranging.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
    }
}
