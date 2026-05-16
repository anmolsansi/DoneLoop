import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var selectedAIMode = "Local + Fallback"
    @State private var remindersEnabled = false

    var body: some View {
        List {
            Section("Google Calendar") {
                settingsRow(
                    title: "Connection",
                    detail: services.calendar.connectionLabel,
                    symbol: "calendar.badge.exclamationmark",
                    status: .calendarDisconnected
                )
            }

            Section("AI Mode") {
                Picker("AI Mode", selection: $selectedAIMode) {
                    Text("Local Only").tag("Local Only")
                    Text("Local + Fallback").tag("Local + Fallback")
                    Text("BYOK").tag("BYOK")
                }
                .pickerStyle(.segmented)
            }

            Section("Working Hours") {
                settingsRow(title: "Preferred hours", detail: "9:00 AM to 5:00 PM", symbol: "clock", status: .notScheduled)
                settingsRow(title: "Default duration", detail: "30 minutes", symbol: "timer", status: .notScheduled)
            }

            Section("Reminders") {
                Toggle("Enable local reminders", isOn: $remindersEnabled)
                settingsRow(title: "Permission", detail: services.notifications.permissionLabel, symbol: "bell", status: .needsDecision)
            }

            Section("Privacy") {
                settingsRow(
                    title: "Local first",
                    detail: "Captures stay on this device unless cloud fallback is enabled.",
                    symbol: "lock",
                    status: .calendarSynced
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(DLColor.background)
        .navigationTitle("Settings")
    }

    private func settingsRow(title: String, detail: String, symbol: String, status: DLStatus) -> some View {
        HStack(spacing: DLSpacing.md) {
            Image(systemName: symbol)
                .foregroundStyle(status.foreground)
            VStack(alignment: .leading, spacing: DLSpacing.xs) {
                Text(title)
                    .foregroundStyle(DLColor.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DLColor.textSecondary)
            }
        }
    }
}
