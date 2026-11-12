import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var controller: ProtectionController

    var body: some View {
        NavigationStack {
            List {
                Section("Unlock Sessions") {
                    if controller.unlockHistory.isEmpty {
                        Text("No unlock sessions yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controller.unlockHistory) { session in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.strictMode ? "Strict unlock" : "Normal unlock")
                                    .font(.headline)
                                Text("Started \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
                                Text("Ended \(session.endedAt?.formatted(date: .omitted, time: .shortened) ?? "Still active")")
                                Text("Target end \(session.unlockUntil.formatted(date: .omitted, time: .shortened))")
                                Text("Magnetic field \(session.magneticMagnitude.formatted(.number.precision(.fractionLength(1)))) uT")
                                Text("Reason: \(session.endReason?.label ?? "Active")")
                            }
                            .font(.subheadline)
                        }
                    }
                }

                Section("Event Log") {
                    if controller.recentEvents.isEmpty {
                        Text("No events yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controller.recentEvents) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.headline)
                                Text(event.detail)
                                    .foregroundStyle(.secondary)
                                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}
