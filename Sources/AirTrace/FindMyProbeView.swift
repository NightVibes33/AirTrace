import SwiftUI
import CoreBluetooth

struct FindMyProbeView: View {
    @ObservedObject var search: SearchCoordinator
    @ObservedObject private var scanner: AirPodsScanner

    init(search: SearchCoordinator) {
        self.search = search
        self.scanner = search.scanner
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    bluetoothStateCard
                    airPodsBeaconSection
                    selectedSection
                    diagnosticsSection
                }
                .padding(18)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .onAppear { scanner.start() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.cyan.opacity(0.14))
                        .frame(width: 58, height: 58)
                    Image(systemName: "airpodspro")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                Spacer()
                Text("FIND MY RADIO")
                    .font(.caption2.bold())
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text("AirTrace")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Closed-case AirPods probe")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Keep the AirPods case closed. AirTrace now looks for Apple Find My 0x12 advertisements whose status bits identify AirPods.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var bluetoothStateCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(scanner.bluetoothState == .poweredOn ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(bluetoothTitle).font(.headline)
                Text(bluetoothSubtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if scanner.isScanning {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var airPodsBeaconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AirPods Find My beacons").font(.title3.bold())
                Spacer()
                Text("\(scanner.findMyBeacons.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.cyan)
            }

            if scanner.findMyBeacons.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 38))
                        .foregroundColor(.cyan)
                    Text("Listening for closed-case AirPods…")
                        .font(.headline)
                    Text("Do not open the case. If Apple 0x12 packets are visible to this iOS build, detected AirPods will appear here automatically.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ForEach(scanner.findMyBeacons) { beacon in
                    Button(action: { search.selectFindMyBeacon(beacon) }) {
                        beaconRow(beacon)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func beaconRow(_ beacon: FindMyAirPodsBeacon) -> some View {
        let selected = search.selectedFindMyBeaconID == beacon.peripheralID
        return HStack(spacing: 13) {
            Image(systemName: "airpodspro")
                .font(.title2)
                .foregroundColor(selected ? .black : .cyan)
                .frame(width: 46, height: 46)
                .background(selected ? Color.cyan : Color.cyan.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 4) {
                Text("AirPods Find My")
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(beacon.state.rawValue)
                    Text("•")
                    Text("\(beacon.packetCount) packets")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                Text(String(beacon.peripheralID.uuidString.prefix(8)))
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(beacon.rssi)")
                    .font(.system(.headline, design: .monospaced))
                Text("dBm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(selected ? Color.cyan.opacity(0.16) : Color.white.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(selected ? Color.cyan : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private var selectedSection: some View {
        if let selected = search.selectedFindMyBeacon {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Selected signal").font(.caption).foregroundColor(.secondary)
                        Text("\(selected.rssi) dBm").font(.title2.bold().monospacedDigit())
                    }
                    Spacer()
                    Button("Clear") { search.clearFindMySelection() }
                        .font(.caption.bold())
                }

                Text("This selection is a radio beacon, not yet cryptographic ownership proof. If multiple AirPods are nearby, choose the beacon whose RSSI changes when you move near your case.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                NavigationLink(destination: FinderScreen(search: search, mode: .guided)) {
                    actionRow(title: "Start 3D Search", subtitle: "Feed this closed-case beacon into AR localization", icon: "viewfinder")
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: FinderScreen(search: search, mode: .precision)) {
                    actionRow(title: "Precision Search", subtitle: "Collect more angles and tighten the probability region", icon: "scope")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func actionRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.cyan)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundColor(.primary)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Radio diagnostics").font(.title3.bold())
            HStack {
                Text("Apple packets observed")
                Spacer()
                Text("\(scanner.totalApplePackets)").monospacedDigit().foregroundColor(.cyan)
            }

            if scanner.applePacketTypeCounts.isEmpty {
                Text("No Apple manufacturer packets have reached CoreBluetooth yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(scanner.applePacketTypeCounts.keys.sorted(), id: \.self) { type in
                    HStack {
                        Text(packetName(type))
                        Spacer()
                        Text("\(scanner.applePacketTypeCounts[type] ?? 0)")
                            .monospacedDigit()
                            .foregroundColor(type == 0x12 ? .cyan : .secondary)
                    }
                    .font(.caption)
                }
            }

            Text("0x12 = Find My. AirTrace only promotes 0x12 frames whose status device-type bits equal 3 (AirPods). Other Apple devices stay in diagnostics and never become search targets.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(15)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var bluetoothTitle: String {
        switch scanner.bluetoothState {
        case .poweredOn: return "Bluetooth scanning"
        case .unauthorized: return "Bluetooth permission denied"
        case .poweredOff: return "Bluetooth is off"
        case .unsupported: return "Bluetooth unavailable"
        default: return "Preparing Bluetooth"
        }
    }

    private var bluetoothSubtitle: String {
        switch scanner.bluetoothState {
        case .poweredOn: return "Scanning every advertisement CoreBluetooth exposes"
        case .unauthorized: return "Enable Bluetooth access for AirTrace in Settings"
        case .poweredOff: return "Turn Bluetooth on and return to AirTrace"
        case .unsupported: return "This device cannot run the BLE scanner"
        default: return "Waiting for iOS Bluetooth state"
        }
    }

    private func packetName(_ type: UInt8) -> String {
        switch type {
        case 0x07: return "0x07 Proximity Pairing"
        case 0x10: return "0x10 Nearby Info"
        case 0x12: return "0x12 Find My"
        default: return String(format: "0x%02X Apple", type)
        }
    }
}
