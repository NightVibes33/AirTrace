import SwiftUI

struct SystemDiscoveryView: View {
    @ObservedObject var search: SearchCoordinator
    @StateObject private var systemProbe = SystemBluetoothProbeModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusCard
                    airPodsSection
                    allDevicesSection
                    controls
                    fallbackSection
                }
                .padding(18)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .onAppear { systemProbe.start() }
            .onDisappear { systemProbe.stop() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.purple.opacity(0.17))
                        .frame(width: 58, height: 58)
                    Image(systemName: "airpodspro")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundColor(.purple)
                }
                Spacer()
                Text("SYSTEM DISCOVERY")
                    .font(.caption2.bold())
                    .foregroundColor(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.14))
                    .clipShape(Capsule())
            }
            Text("AirTrace")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Apple FindNearbyRemote probe")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("This build bypasses the normal CBCentralManager discovery path and asks CoreBluetooth's private system discovery service for Find Nearby samples and RSSI.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(systemProbe.active ? "System discovery active" : "System discovery status")
                    .font(.headline)
                Spacer()
                Text("\(systemProbe.eventCount) events")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Text(systemProbe.status)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .foregroundColor(systemProbe.status.lowercased().contains("denied") || systemProbe.status.lowercased().contains("error") ? .orange : .secondary)

            HStack {
                Label(systemProbe.available ? "CBDiscovery present" : "CBDiscovery missing", systemImage: systemProbe.available ? "checkmark.circle.fill" : "xmark.circle.fill")
                Spacer()
                Label(systemProbe.active ? "XPC active" : "XPC inactive", systemImage: systemProbe.active ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(15)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var airPodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AirPods candidates").font(.title3.bold())
                Spacer()
                Text("\(systemProbe.airPodsCandidates.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.purple)
            }

            if systemProbe.airPodsCandidates.isEmpty {
                VStack(spacing: 11) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 35))
                        .foregroundColor(.purple)
                    Text(systemProbe.eventCount == 0 ? "Waiting for system Bluetooth samples…" : "System samples arrived, but none identify as AirPods yet.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Keep the case closed. Do not put the AirPods into pairing mode. This path is testing the same private Find Nearby discovery class used by Apple system components.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(systemProbe.airPodsCandidates) { device in
                    deviceCard(device, highlight: true)
                }
            }
        }
    }

    private var allDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Raw CBDevice feed").font(.title3.bold())
                Spacer()
                Text("\(systemProbe.devices.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            if systemProbe.devices.isEmpty {
                Text("No CBDevice objects received yet. If the status above reports an XPC/authorization error, iOS is gating this private scan from the SideStore process.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(systemProbe.devices.prefix(25)) { device in
                    deviceCard(device, highlight: device.looksLikeAirPods)
                }
            }
        }
    }

    private func deviceCard(_ device: SystemBluetoothDevice, highlight: Bool) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 7) {
                detail("Identifier", device.identifier)
                detail("Runtime", device.runtimeClass)
                detail("Model", device.model)
                detail("Product", device.productName)
                detail("Product ID", hex(device.productID))
                detail("ProxPair product", hex(device.proximityPairingProductID))
                detail("Object product", hex(device.objectDiscoveryProductID))
                detail("Find My case", device.findMyCaseIdentifier)
                detail("Find My group", device.findMyGroupIdentifier)
                detail("Apple mfg", truncated(device.appleManufacturerHex))
                detail("Advertisement", truncated(device.advertisementHex))
                if !device.airPodsEvidence.isEmpty {
                    detail("AirPods evidence", device.airPodsEvidence.joined(separator: ", "))
                }
                if !device.rawDescription.isEmpty {
                    Text(device.rawDescription)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: highlight ? "airpodspro" : "antenna.radiowaves.left.and.right")
                    .foregroundColor(highlight ? .purple : .secondary)
                    .frame(width: 35)
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.displayName).font(.headline).lineLimit(1)
                    Text(device.identifier)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let rssi = device.rssi {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(rssi)").font(.headline.monospacedDigit())
                        Text("dBm").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(highlight ? Color.purple.opacity(0.13) : Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(highlight ? Color.purple.opacity(0.6) : Color.clear, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: { systemProbe.start() }) {
                Label("Restart probe", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .tint(.purple)

            Button(action: { systemProbe.stop() }) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(BorderedButtonStyle())
        }
    }

    private var fallbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comparison test").font(.headline)
            Text("The old public CoreBluetooth scanner is still available only for comparison. The system probe above is the test that matters in this build.")
                .font(.caption)
                .foregroundColor(.secondary)
            NavigationLink(destination: FindMyProbeView(search: search)) {
                HStack {
                    Text("Open public CoreBluetooth diagnostics")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.bold())
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var statusColor: Color {
        if systemProbe.active { return .green }
        let lower = systemProbe.status.lowercased()
        if lower.contains("denied") || lower.contains("error") || lower.contains("invalidated") { return .red }
        return .orange
    }

    @ViewBuilder private func detail(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(title).foregroundColor(.secondary).frame(width: 105, alignment: .leading)
                Text(value).textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .font(.caption)
        }
    }

    private func hex(_ value: UInt64?) -> String? {
        guard let value else { return nil }
        return String(format: "0x%llX (%llu)", value, value)
    }

    private func truncated(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.count <= 96 { return value }
        return String(value.prefix(96)) + "…"
    }
}
