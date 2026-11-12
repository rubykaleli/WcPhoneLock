import FamilyControls
import SwiftUI

private enum HomeSheet: String, Identifiable {
    case calibration
    case settings
    case history
    case installWifiShortcut

    var id: String { rawValue }
}

struct HomeView: View {
    @EnvironmentObject private var controller: ProtectionController
    @State private var activeSheet: HomeSheet?
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroCard
                    scannerButton
                    if controller.pendingVerificationRequest {
                        VerifyPromptCard { controller.requestVerificationScan() }
                    }
                    setupCard
                    if controller.isUnlockActive {
                        unlockedCard
                    }
                    recentActivityCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.15, blue: 0.35),
                        Color(red: 0.1, green: 0.25, blue: 0.5),
                        Color(red: 0.15, green: 0.35, blue: 0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("PoopLock")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { activeSheet = .history } label: {
                        Image(systemName: "clock.arrow.circlepath").font(.headline)
                    }
                    Button { activeSheet = .settings } label: {
                        Image(systemName: "gearshape.fill").font(.headline)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .calibration:
                    CalibrationSheetView(verificationManager: controller.verificationManager)
                        .environmentObject(controller)
                case .settings:
                    SimpleSettingsSheet()
                        .environmentObject(controller)
                case .history:
                    HistoryView()
                        .environmentObject(controller)
                case .installWifiShortcut:
                    InstallWifiShortcutSheet { activeSheet = .settings }
                        .environmentObject(controller)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                Text("💩")
                    .font(.system(size: 54))
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PoopLock")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("Bathroom shield for your apps.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                Spacer()
            }

            Toggle(isOn: protectionBinding) {
                Text("PoopLock is Armed")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .toggleStyle(.switch)
            .tint(Color(red: 1.0, green: 0.7, blue: 0.2))

            statusPill(
                title: controller.effectiveInsideHome ? "At home" : "Away from home",
                subtitle: controller.statusSummary,
                color: controller.effectiveInsideHome ? Color.green : Color.white.opacity(0.2)
            )

            Text(controller.lastMessage)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.84))
        }
        .padding(20)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.9),
                        Color(red: 0.2, green: 0.5, blue: 0.9),
                        Color(red: 0.3, green: 0.6, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle().fill(Color.white.opacity(0.18)).frame(width: 110).offset(x: 110, y: -70)
                Circle().fill(Color.white.opacity(0.14)).frame(width: 70).offset(x: -120, y: 60)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .foregroundStyle(.white)
    }

    private var scannerButton: some View {
        VStack(spacing: 20) {
            ZStack {
                if controller.verificationManager.isScanning {
                    Circle()
                        .stroke(Color.blue.opacity(0.5), lineWidth: 4)
                        .frame(width: 220, height: 220)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0.0 : 1.0)

                    Circle()
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 4)
                        .frame(width: 220, height: 220)
                        .scaleEffect(isPulsing ? 1.2 : 0.8)
                        .opacity(isPulsing ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 1.2).delay(0.3).repeatForever(autoreverses: false), value: isPulsing)
                }

                Button(action: primaryAction) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: controller.verificationManager.isScanning
                                        ? [Color.cyan, Color.blue]
                                        : [Color.white, Color(red: 0.9, green: 0.95, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 200, height: 200)
                            .shadow(
                                color: controller.verificationManager.isScanning ? Color.cyan.opacity(0.6) : Color.black.opacity(0.15),
                                radius: 20,
                                y: 10
                            )

                        VStack(spacing: 12) {
                            Text(controller.verificationManager.isScanning ? "🚽" : "🧻")
                                .font(.system(size: 64))
                                .rotationEffect(.degrees(controller.verificationManager.isScanning ? rotationAngle : 0))

                            Text(controller.verificationManager.isScanning ? "SCANNING..." : primaryButtonTitle)
                                .font(.headline.weight(.black))
                                .foregroundStyle(controller.verificationManager.isScanning ? .white : Color(red: 0.2, green: 0.3, blue: 0.5))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled((controller.isUnlockActive && controller.calibration.isReady) || controller.verificationManager.isScanning || controller.pendingVerificationScan)
            }
            .padding(.vertical, 20)

            Text(primaryActionSubtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    private var setupCard: some View {
        FunCard(background: Color.white.opacity(0.94)) {
            VStack(alignment: .leading, spacing: 16) {
                Text("🛠️ Quick setup").font(.headline)

                setupRow(
                    title: "Save home",
                    subtitle: controller.settings.homeCoordinate == nil ? "Tell PoopLock where home is." : "Home is saved and ready.",
                    ready: controller.settings.homeCoordinate != nil,
                    buttonTitle: "Save Home"
                ) {
                    controller.homeLocationManager.requestCurrentLocation()
                    controller.saveHomeFromCurrentLocation()
                }

                Divider()

                setupRow(
                    title: "Teach your bathroom",
                    subtitle: controller.calibration.isReady ? "Bathroom check is ready." : "Save one normal room and one bathroom sample.",
                    ready: controller.calibration.isReady,
                    buttonTitle: "Setup"
                ) {
                    activeSheet = .calibration
                }

                Divider()

                setupRow(
                    title: "Wi‑Fi shortcut",
                    subtitle: "Optional iOS Shortcut for live dBm signal import.",
                    ready: true,
                    buttonTitle: "Install"
                ) {
                    activeSheet = .installWifiShortcut
                }

                Divider()

                if BuildFlavor.isLocalTesting {
                    setupRow(
                        title: "Phone testing",
                        subtitle: "Local testing mode on this iPhone.",
                        ready: true,
                        buttonTitle: "Open"
                    ) {
                        activeSheet = .settings
                    }
                } else {
                    let appsReady = !(controller.screenTimeManager.selection.applicationTokens.isEmpty &&
                                      controller.screenTimeManager.selection.webDomainTokens.isEmpty)
                    setupRow(
                        title: "Pick blocked apps",
                        subtitle: appsReady ? "Your blocked apps are selected." : "Choose apps you want blocked inside the bathroom.",
                        ready: appsReady,
                        buttonTitle: "Choose"
                    ) {
                        activeSheet = .settings
                    }
                }
            }
        }
    }

    private var unlockedCard: some View {
        FunCard(background: Color(red: 0.87, green: 1.0, blue: 0.90)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("✅ You are clear to scroll")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.07, green: 0.44, blue: 0.22))

                if let unlockUntil = controller.unlockUntil {
                    Text("Your apps are unlocked until \(unlockUntil.formatted(date: .omitted, time: .shortened)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recentActivityCard: some View {
        FunCard(background: Color.white.opacity(0.92)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("📜 What PoopLock noticed").font(.headline)
                    Spacer()
                    Button("All activity") { activeSheet = .history }
                        .font(.subheadline.weight(.semibold))
                }

                if controller.recentEvents.isEmpty {
                    Text("Nothing yet. Run calibration to start tracking checks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let events = Array(controller.recentEvents.prefix(3))
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.subheadline.weight(.semibold))
                            Text(event.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                        if event.id != events.last?.id { Divider() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func setupRow(title: String, subtitle: String, ready: Bool, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(ready ? Color.green : Color.orange)
                .frame(width: 18, height: 18)
                .overlay {
                    if ready {
                        Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(.white)
                    }
                }
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()

            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func statusPill(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.bold))
            Text(subtitle).font(.footnote).foregroundStyle(Color.white.opacity(0.88))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 18))
    }

    private var protectionBinding: Binding<Bool> {
        Binding(get: { controller.settings.protectionEnabled }, set: { controller.setProtectionEnabled($0) })
    }

    private var primaryActionSubtitle: String {
        if controller.pendingVerificationScan {
            return "Shortcuts is running — room check starts automatically when Wi‑Fi data returns."
        }
        if !controller.calibration.isReady {
            return "Tap above to calibrate a safe room and bathroom baseline."
        }
        return "Tap to run a quick sensor check before unlocking."
    }

    private var primaryButtonTitle: String {
        if !controller.calibration.isReady { return "SET UP" }
        if controller.isUnlockActive { return "CLEAR" }
        return "SCAN ROOM"
    }

    private func primaryAction() {
        if !controller.calibration.isReady {
            activeSheet = .calibration
            return
        }
        controller.requestVerificationScan()
    }
}
