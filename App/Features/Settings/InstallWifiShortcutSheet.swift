import SwiftUI
import UIKit

struct InstallWifiShortcutSheet: View {
    @EnvironmentObject private var controller: ProtectionController
    @Environment(\.dismiss) private var dismiss
    @State private var showRecipe = false

    let onOpenSettings: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("PoopLock Wi‑Fi shortcut")
                    .font(.title2.weight(.bold))

                Text("If you don’t have a PoopLock shortcut in Shortcuts yet, build one from the recipe below or import a shared shortcut file.")
                    .font(.body)

                Text("Apple restricts direct Wi‑Fi signal reads from apps, so PoopLock uses an Apple Shortcut that passes Wi‑Fi telemetry back over `pooplock://wifi?dbm=…`. Tap Allow the first time iOS prompts.")
                    .font(.body)

                Group {
                    if hasHostedShortcutURL {
                        Text("An import URL is configured. Tap Install to open Shortcuts and add it.")
                    } else if PoopLockWifiShortcut.bundledShortcutFileURL != nil {
                        Text("This build bundles PoopLockWIFI.shortcut. Tap Install to import it or Share to open it in Shortcuts.")
                    } else {
                        Text("Until a hosted shortcut URL or bundled `.shortcut` file is added, Install opens the build recipe.")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                if let bundled = PoopLockWifiShortcut.bundledShortcutFileURL {
                    ShareLink(item: bundled, preview: SharePreview("PoopLockWIFI.shortcut", icon: Image(systemName: "square.stack.3d.up"))) {
                        Label("Share shortcut file to Shortcuts", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: runInstallFlow) {
                    Text("Install")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button("View build steps (recipe)") {
                    showRecipe = true
                }

                Button("Full settings (name, iCloud link, test)") {
                    dismiss()
                    DispatchQueue.main.async {
                        onOpenSettings()
                    }
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showRecipe) {
                ShortcutRecipeSheet(isPresented: $showRecipe)
            }
        }
    }

    private var hasHostedShortcutURL: Bool {
        let official = PoopLockWifiShortcut.officialImportURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = controller.settings.wifiShortcutImportURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !official.isEmpty || !user.isEmpty
    }

    private func runInstallFlow() {
        let official = PoopLockWifiShortcut.officialImportURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = controller.settings.wifiShortcutImportURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !official.isEmpty {
            ShortcutOpener.importShortcut(fromSharedLink: official)
            dismiss()
            return
        }
        if !user.isEmpty {
            controller.importWifiShortcutFromConfiguredLink()
            dismiss()
            return
        }
        if ShortcutOpener.importBundledShortcutFromAppBundle() {
            dismiss()
            return
        }
        showRecipe = true
        controller.openShortcutsApp()
    }
}

struct ShortcutRecipeSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(ShortcutRecipeContent.fullInstructions)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("PoopLock Wi‑Fi shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Copy all") {
                        UIPasteboard.general.string = ShortcutRecipeContent.fullInstructions
                    }
                }
            }
        }
    }
}

