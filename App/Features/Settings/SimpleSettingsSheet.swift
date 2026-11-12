import FamilyControls
import SwiftUI
import UIKit

struct SimpleSettingsSheet: View {
    @EnvironmentObject private var controller: ProtectionController
    @Environment(\.dismiss) private var dismiss
    @State private var isPickerPresented = false
    @State private var showShortcutRecipe = false

    private var isWifiShortcutNameSetToWifimanTesting: Bool {
        let normalized = ShortcutOpener.normalizedShortcutDisplayName(controller.settings.wifiShortcutName)
        return normalized == PoopLockWifiShortcut.wifimanShortcutNameForTesting
            || normalized == PoopLockWifiShortcut.wifimanShortcutAlternateNameForTesting
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Protection") {
                    Toggle("PoopLock On", isOn: protectionBinding)
                    Toggle("Strict Mode", isOn: strictModeBinding)

                    Stepper(value: unlockDurationBinding, in: 5...60, step: 5) {
                        Text("Unlock duration: \(controller.settings.unlockDurationMinutes) minutes")
                    }
                }

                Section("Home") {
                    Button("Use Current Place as Home") {
                        controller.homeLocationManager.requestCurrentLocation()
                        controller.saveHomeFromCurrentLocation()
                    }
                }

                Section("Local network & Bluetooth") {
                    Text("Use the button below to re-trigger iOS Local Network and Bluetooth permission prompts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Show Local Network & Bluetooth prompts") {
                        controller.promptLocalNetworkAndBluetoothPermissions()
                    }
                }

                Section("Wi‑Fi shortcut") {
                    Button("View full shortcut recipe (steps + URL)") {
                        showShortcutRecipe = true
                    }

                    TextField("Exact name in Shortcuts app", text: wifiShortcutNameBinding)
                        .textInputAutocapitalization(.never)

                    if isWifiShortcutNameSetToWifimanTesting {
                        Text("Currently set to a WiFiman debug shortcut name. Tap “Use PoopLock name” to switch back.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Button {
                        controller.setWifiShortcutName(PoopLockWifiShortcut.defaultName)
                        UIPasteboard.general.string = PoopLockWifiShortcut.defaultName
                    } label: {
                        Text("Use PoopLock name: \(PoopLockWifiShortcut.defaultName)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)

                    Toggle("Skip Shortcuts app for scans (recommended)", isOn: skipShortcutsForScansBinding)
                    Toggle("Use on‑device Wi‑Fi if Shortcuts didn’t return pooplock://wifi", isOn: nativeWifiFallbackBinding)

                    TextField("iCloud shortcut link (optional import)", text: wifiShortcutImportURLBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let bundled = PoopLockWifiShortcut.bundledShortcutFileURL {
                        ShareLink(item: bundled, preview: SharePreview("PoopLockWIFI.shortcut", icon: Image(systemName: "square.stack.3d.up"))) {
                            Label("Share bundled PoopLockWIFI.shortcut", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button("Add shortcut from link") {
                        controller.importWifiShortcutFromConfiguredLink()
                    }
                    .disabled(controller.settings.wifiShortcutImportURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Test: run Wi‑Fi shortcut now") {
                        controller.runConfiguredWifiShortcut()
                    }

                    Button("Open Shortcuts app") {
                        controller.openShortcutsApp()
                    }

                    Button("Copy sample URL") {
                        UIPasteboard.general.string = ShortcutRecipeContent.minimalUrlExample
                    }

                    if let w = controller.shortcutWifiReading {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("Last Wi‑Fi payload") {
                                Text(w.shortSummary).monospacedDigit()
                            }
                            if let metrics = w.metricsSummary {
                                LabeledContent("Metrics") {
                                    Text(metrics).font(.caption.monospacedDigit())
                                }
                            }
                            if let bssid = w.bssid, !bssid.isEmpty {
                                LabeledContent("BSSID") {
                                    Text(bssid).font(.caption.monospacedDigit())
                                }
                            }
                        }
                    }
                }

                if BuildFlavor.isLocalTesting {
                    Section("Testing") {
                        Toggle("🏠 Pretend I'm Home", isOn: localTestingHomeBinding)
                        Button("🚨 Show Verify Prompt") {
                            controller.triggerVerificationPromptForTesting()
                        }
                    }
                } else {
                    Section("Apps") {
                        Button("Choose Apps to Block") {
                            isPickerPresented = true
                        }
                    }
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: selectionBinding)
            .navigationTitle("PoopLock Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShortcutRecipe) {
                ShortcutRecipeSheet(isPresented: $showShortcutRecipe)
            }
        }
    }

    private var protectionBinding: Binding<Bool> {
        Binding(get: { controller.settings.protectionEnabled }, set: { controller.setProtectionEnabled($0) })
    }

    private var strictModeBinding: Binding<Bool> {
        Binding(get: { controller.settings.strictMode }, set: { controller.setStrictMode($0) })
    }

    private var unlockDurationBinding: Binding<Int> {
        Binding(get: { controller.settings.unlockDurationMinutes }, set: { controller.updateUnlockDuration(minutes: $0) })
    }

    private var selectionBinding: Binding<FamilyActivitySelection> {
        Binding(get: { controller.screenTimeManager.selection }, set: { controller.updateSelection($0) })
    }

    private var localTestingHomeBinding: Binding<Bool> {
        Binding(get: { controller.settings.localTestingForceHome }, set: { controller.setLocalTestingForceHome($0) })
    }

    private var wifiShortcutNameBinding: Binding<String> {
        Binding(get: { controller.settings.wifiShortcutName }, set: { controller.setWifiShortcutName($0) })
    }

    private var wifiShortcutImportURLBinding: Binding<String> {
        Binding(get: { controller.settings.wifiShortcutImportURL }, set: { controller.setWifiShortcutImportURL($0) })
    }

    private var nativeWifiFallbackBinding: Binding<Bool> {
        Binding(
            get: { controller.settings.useNativeWifiFallbackWhenShortcutMissing },
            set: { controller.setUseNativeWifiFallbackWhenShortcutMissing($0) }
        )
    }

    private var skipShortcutsForScansBinding: Binding<Bool> {
        Binding(
            get: { !controller.settings.shouldOpenShortcutsBeforeScan },
            set: { controller.setOpenShortcutsBeforeWifiScans(!$0) }
        )
    }
}

