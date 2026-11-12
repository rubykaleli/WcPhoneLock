import SwiftUI

struct VerifyPromptCard: View {
    let onCheckNow: () -> Void

    var body: some View {
        FunCard(background: Color(red: 1.0, green: 0.96, blue: 0.80)) {
            VStack(alignment: .leading, spacing: 10) {
                Text("🚨 Time for a throne check!")
                    .font(.headline)

                Text("A locked app asked for verification. Run a quick scan and PoopLock will decide if you are clear.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FunPillButton(
                    title: "Check Now",
                    color: Color(red: 0.99, green: 0.58, blue: 0.20),
                    action: onCheckNow
                )
            }
        }
    }
}

