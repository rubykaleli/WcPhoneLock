import SwiftUI

@main
struct RestroomRestrictionApp: App {
    @StateObject private var controller = ProtectionController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .task {
                    controller.requestPermissions()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        controller.syncSharedState()
                    }
                }
                .onOpenURL { url in
                    controller.handleIncomingShortcutURL(url)
                }
        }
    }
}
