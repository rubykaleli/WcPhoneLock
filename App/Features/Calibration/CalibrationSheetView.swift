import CoreMotion
import SwiftUI

private enum CalibrationStep: Int, CaseIterable {
    case welcome
    case safeZoneSpot1
    case safeZoneSpot2
    case bathroomSpot1
    case bathroomSpot2
    case done
}

struct CalibrationSheetView: View {
    @EnvironmentObject private var controller: ProtectionController
    @ObservedObject private var verificationManager: RoomVerificationManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: CalibrationStep = .welcome
    @State private var roomName = "Living room"

    init(verificationManager: RoomVerificationManager) {
        _verificationManager = ObservedObject(wrappedValue: verificationManager)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                switch currentStep {
                case .welcome:
                    welcomeView
                case .safeZoneSpot1:
                    scanView(
                        title: "Safe Zone: Spot 1",
                        subtitle: "Go to your bedroom or living room. Stand in your favorite spot.",
                        isBathroom: false
                    )
                case .safeZoneSpot2:
                    scanView(
                        title: "Safe Zone: Spot 2",
                        subtitle: "Stay in the same room, but move to a different spot (like near the door).",
                        isBathroom: false
                    )
                case .bathroomSpot1:
                    scanView(
                        title: "Danger Zone: Spot 1",
                        subtitle: "Go to the bathroom. Sit on the toilet exactly how you normally would.",
                        isBathroom: true
                    )
                case .bathroomSpot2:
                    scanView(
                        title: "Danger Zone: Spot 2",
                        subtitle: "Stay in the bathroom. Stand up near the sink or the door.",
                        isBathroom: true
                    )
                case .done:
                    doneView
                }

                Spacer()
            }
            .padding(24)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Teach PoopLock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: currentStep) { _, newStep in
                roomName = Self.defaultRoomLabel(for: newStep)
            }
            .onChange(of: controller.calibrationScanCompletedSignal) { _, _ in
                withAnimation {
                    if let next = CalibrationStep(rawValue: currentStep.rawValue + 1) {
                        currentStep = next
                    }
                }
            }
        }
    }

    private var buttonLabel: String {
        if verificationManager.isScanning { return "Scanning…" }
        if controller.pendingCalibrationScan != nil { return "Waiting for shortcut…" }
        return "Scan Room"
    }

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Text("🎯")
                .font(.system(size: 64))

            Text("Let's map your house")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("You will name each room, then tap Scan. PoopLock opens your Wi‑Fi shortcut, then when you come back it records a 10-second sensor sample. Install a shortcut named “\(PoopLockWifiShortcut.defaultName)” that ends with Open URL → pooplock://wifi?dbm=…")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                withAnimation { currentStep = .safeZoneSpot1 }
            } label: {
                Text("Start Calibration")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 20)
        }
    }

    private func scanView(title: String, subtitle: String, isBathroom: Bool) -> some View {
        VStack(spacing: 32) {
            Text(isBathroom ? "🚽" : "🛋️")
                .font(.system(size: 64))

            VStack(spacing: 8) {
                Text(title).font(.title2.bold())
                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Room name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. Kitchen, Bedroom", text: $roomName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(verificationManager.isScanning)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if controller.pendingCalibrationScan != nil {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Open Shortcuts — PoopLock continues right after Wi‑Fi is sent back.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Tap Scan to open Shortcuts; when the shortcut returns to PoopLock, the 10s scan starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: verificationManager.scanProgress)
                    .stroke(isBathroom ? Color.orange : Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                if verificationManager.isScanning {
                    Text("\(min(10, max(0, Int(ceil(verificationManager.liveDebug.secondsElapsed)))))s")
                        .font(.title.bold())
                        .monospacedDigit()
                } else {
                    Text("Ready")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 20)

            if verificationManager.isScanning {
                scanDebugPanel
            }

            Button {
                controller.requestCalibrationScan(isBathroom: isBathroom, roomLabel: roomName)
            } label: {
                Text(buttonLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isBathroom ? .orange : .blue)
            .controlSize(.large)
            .disabled(verificationManager.isScanning || controller.pendingCalibrationScan != nil)
        }
    }

    @ViewBuilder
    private var scanDebugPanel: some View {
        let d = verificationManager.liveDebug
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan status")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            scanRow(title: "Network", value: d.networkPathSummary, done: d.secondsElapsed >= 0.5)
            scanRow(
                title: "Magnetometer",
                value: d.magnetometerMicroteslas.map { String(format: "%.1f µT", $0) } ?? "…",
                done: d.sampleCountMag > 0
            )
            scanRow(
                title: "Pressure (barometer)",
                value: d.pressureHectopascals.map { String(format: "%.2f hPa", $0) } ?? (CMAltimeter.isRelativeAltitudeAvailable() ? "…" : "Not available"),
                done: d.sampleCountPressure > 0 || !CMAltimeter.isRelativeAltitudeAvailable()
            )
            scanRow(
                title: "Wi‑Fi (this iPhone)",
                value: d.nativeWifiSummary,
                done: d.nativeWifiSummary != "…" && d.nativeWifiSummary != "Unavailable"
            )
            if let w = controller.shortcutWifiReading {
                scanRow(title: "Wi‑Fi (Shortcuts — used for dBm match)", value: w.shortSummary, done: true)
                if let metrics = w.metricsSummary {
                    scanRow(title: "Shortcuts metrics", value: metrics, done: true)
                }
                if let identity = w.identitySummary {
                    scanRow(title: "Shortcuts AP", value: identity, done: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func scanRow(title: String, value: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            Text(title).font(.caption.weight(.medium))
            Spacer()
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(.primary)
        }
    }

    private var doneView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("✅").font(.system(size: 64))
                Text("All Set!").font(.title2.bold())
                Text("Here is what we stored per room. If you used a Shortcuts import, dBm drives matching; otherwise on-device Wi‑Fi strength — plus magnetometer and barometer.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                calibrationSummaryList

                Button {
                    dismiss()
                } label: {
                    Text("Finish").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(.vertical, 8)
        }
    }

    private var calibrationSummaryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Home / safe spots").font(.subheadline.weight(.bold))
            ForEach(Array(controller.calibration.safeZoneSamples.enumerated()), id: \.offset) { _, sample in
                calibrationSampleRow(sample)
            }
            Text("Bathroom").font(.subheadline.weight(.bold)).padding(.top, 4)
            ForEach(Array(controller.calibration.bathroomSamples.enumerated()), id: \.offset) { _, sample in
                calibrationSampleRow(sample)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func calibrationSampleRow(_ sample: VerificationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sample.roomLabel ?? "Room").font(.subheadline.weight(.semibold))
            Text(String(format: "Magnet: %.1f µT", sample.magneticMagnitude)).font(.caption)
            if let native = sample.nativeWifi {
                Text("Wi‑Fi: \(native.shortSummary)").font(.caption).foregroundStyle(.secondary)
            }
            if let reading = sample.wifiReading {
                Text("Shortcuts: \(reading.shortSummary)").font(.caption2).foregroundStyle(.tertiary)
            } else if let w = sample.wifiDbm {
                Text("Shortcuts dBm: \(Int(w))").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private static func defaultRoomLabel(for step: CalibrationStep) -> String {
        switch step {
        case .welcome, .done: ""
        case .safeZoneSpot1, .safeZoneSpot2: "Living room"
        case .bathroomSpot1, .bathroomSpot2: "Bathroom"
        }
    }
}

