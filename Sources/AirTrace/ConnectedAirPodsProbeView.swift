import SwiftUI

struct ConnectedAirPodsProbeView: View {
    @ObservedObject var search: SearchCoordinator
    @StateObject private var probe = ConnectedAirPodsProbeModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    routeCard
                    managerCard
                    connectedSection
                    allSection
                    rawSection
                    fallback
                }
                .padding(18)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .onAppear { probe.start() }
            .onDisappear { probe.stop() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "airpodspro")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(width: 58, height: 58)
                    .background(Color.green.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Spacer()
                Text("CONNECTED PATH")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text("AirTrace")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Paired + connected AirPods probe")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("This build does not depend on BLE discovery. It asks iOS for the headphones already paired/connected to this phone, then inspects their internal CBDevice for live RSSI and Find My metadata.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Public audio route").font(.headline)
            if probe.audioRoutes.isEmpty {
                Text("No active Bluetooth audio output in AVAudioSession.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(probe.audioRoutes, id: \.self) { route in
                    Text(route)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
            Text(probe.status)
                .font(.caption)
                .foregroundColor(probe.bestLiveRSSI != nil ? .green : .orange)
        }
        .padding(15)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var managerCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("System backends").font(.headline)
            statusRow("HeadphoneManager framework", probe.headphoneManagerLoaded)
            statusRow("HPMHeadphoneManager.shared", probe.headphoneManagerInstance)
            statusRow("BluetoothManager framework", probe.bluetoothManagerLoaded)
            statusRow("BluetoothManager.sharedInstance", probe.bluetoothManagerInstance)
        }
        .padding(15)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Connected AirPods").font(.title3.bold())
                Spacer()
                Text("\(probe.connectedAirPods.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.green)
            }

            if probe.connectedAirPods.isEmpty {
                Text("No connected AirPods object reached either private system manager yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(probe.connectedAirPods) { record in recordCard(record, highlight: true) }
            }
        }
    }

    private var allSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All paired/system records").font(.title3.bold())
            if probe.records.isEmpty {
                Text("No records returned.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(probe.records) { record in recordCard(record, highlight: false) }
            }
        }
    }

    private func recordCard(_ record: ConnectedAirPodsRecord, highlight: Bool) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                line("Source", record.source)
                line("Connected", record.connected ? "YES" : "NO")
                line("Genuine AirPods", record.genuineAirPods ? "YES" : "NO")
                if let rssi = record.rssi { line("CBDevice RSSI", "\(rssi) dBm") }
                if let productID = record.productID { line("Product ID", String(format: "0x%llX", productID)) }
                if let value = record.caseBattery { line("Case battery", String(format: "%.0f%%", value * (value <= 1 ? 100 : 1))) }
                if let value = record.leftBattery { line("Left battery", String(format: "%.0f%%", value * (value <= 1 ? 100 : 1))) }
                if let value = record.rightBattery { line("Right battery", String(format: "%.0f%%", value * (value <= 1 ? 100 : 1))) }
                if let value = record.findMyCaseIdentifier, !value.isEmpty { line("Find My case ID", value) }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: record.genuineAirPods ? "airpodspro" : "headphones")
                    .foregroundColor(highlight ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.name).font(.headline).lineLimit(1)
                    Text(record.source).font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                if let rssi = record.rssi {
                    Text("\(rssi) dBm").font(.headline.monospacedDigit()).foregroundColor(.green)
                }
            }
        }
        .padding(14)
        .background(highlight ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var rawSection: some View {
        DisclosureGroup("Raw system snapshot") {
            Text(probe.rawJSON)
                .font(.caption2.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
        .padding(15)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var fallback: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Older probes").font(.headline)
            NavigationLink("Open CBDiscovery system probe") {
                SystemDiscoveryView(search: search)
            }
            NavigationLink("Open public CoreBluetooth probe") {
                FindMyProbeView(search: search)
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func statusRow(_ title: String, _ ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(ok ? .green : .red)
            Text(title)
            Spacer()
        }
        .font(.caption)
    }

    @ViewBuilder private func line(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(title).foregroundColor(.secondary).frame(width: 105, alignment: .leading)
                Text(value).textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .font(.caption)
        }
    }
}
