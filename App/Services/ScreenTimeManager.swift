import FamilyControls
import Foundation

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published var selection: FamilyActivitySelection
    @Published private(set) var authorizationStatus: AuthorizationStatus

    init() {
        self.selection = AppGroupStore.loadSelection()
        #if LOCAL_TESTING
        self.authorizationStatus = .approved
        #else
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        #endif
    }

    func requestAuthorization() async {
        #if !LOCAL_TESTING
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            AppGroupStore.appendEvent(
                VerificationEvent(
                    title: "Screen Time authorization failed",
                    detail: error.localizedDescription
                )
            )
        }
        #endif
    }

    func updateSelection(_ selection: FamilyActivitySelection) {
        self.selection = selection
        AppGroupStore.saveSelection(selection)
    }
}
