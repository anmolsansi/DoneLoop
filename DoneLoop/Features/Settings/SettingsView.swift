import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var services: AppServices

    var body: some View {
        List {
            Section("Google Calendar") {
                settingsRow(
                    title: "Connection",
                    detail: services.localStore.settings.googleCalendarID == nil ? services.calendar.connectionLabel : "Connected",
                    symbol: "calendar.badge.exclamationmark",
                    status: services.localStore.settings.googleCalendarID == nil ? .calendarDisconnected : .calendarSynced
                )
            }

            Section("AI Mode") {
                Picker("AI Mode", selection: aiModeBinding) {
                    Text("Local Only").tag(DLAIMode.localOnly)
                    Text("Local + Fallback").tag(DLAIMode.localWithFallback)
                    Text("BYOK").tag(DLAIMode.bringYourOwnKey).disabled(true)
                }
                .pickerStyle(.segmented)

                settingsRow(
                    title: services.localStore.settings.aiMode.displayName,
                    detail: services.aiRouter.modeDetail(for: services.localStore.settings),
                    symbol: "cpu",
                    status: .needsDecision
                )
            }

            Section("Working Hours") {
                Stepper(value: workStartBinding, in: 0...23) {
                    settingsRow(title: "Work starts", detail: hourLabel(services.localStore.settings.preferredWorkStartHour), symbol: "sunrise", status: .notScheduled)
                }

                Stepper(value: workEndBinding, in: 1...23) {
                    settingsRow(title: "Work ends", detail: hourLabel(services.localStore.settings.preferredWorkEndHour), symbol: "sunset", status: .notScheduled)
                }

                Stepper(value: defaultDurationBinding, in: 5...180, step: 5) {
                    settingsRow(
                        title: "Default duration",
                        detail: "\(services.localStore.settings.defaultTaskDurationMinutes) minutes",
                        symbol: "timer",
                        status: .notScheduled
                    )
                }
            }

            Section("Reminders") {
                Toggle("Enable local reminders", isOn: remindersBinding)
                settingsRow(title: "Permission", detail: services.notifications.permissionLabel, symbol: "bell", status: .needsDecision)
            }

            Section("Privacy") {
                settingsRow(
                    title: "Local first",
                    detail: "Captures stay on this device unless cloud fallback is enabled.",
                    symbol: "lock",
                    status: .calendarSynced
                )
                settingsRow(
                    title: "No account required",
                    detail: "V1 uses local storage and does not require a backend.",
                    symbol: "iphone",
                    status: .calendarSynced
                )
            }

            Section("App") {
                settingsRow(title: "Version", detail: "0.1.0", symbol: "info.circle", status: .notScheduled)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DLColor.background)
        .navigationTitle("Settings")
    }

    private var aiModeBinding: Binding<DLAIMode> {
        Binding(
            get: { services.localStore.settings.aiMode },
            set: { mode in
                guard mode != .bringYourOwnKey else { return }
                services.localStore.updateSettings { settings in
                    settings.aiMode = mode
                }
            }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { services.localStore.settings.remindersEnabled },
            set: { enabled in
                services.localStore.updateSettings { settings in
                    settings.remindersEnabled = enabled
                }
            }
        )
    }

    private var workStartBinding: Binding<Int> {
        Binding(
            get: { services.localStore.settings.preferredWorkStartHour },
            set: { hour in
                services.localStore.updateSettings { settings in
                    settings.preferredWorkStartHour = min(hour, settings.preferredWorkEndHour - 1)
                }
            }
        )
    }

    private var workEndBinding: Binding<Int> {
        Binding(
            get: { services.localStore.settings.preferredWorkEndHour },
            set: { hour in
                services.localStore.updateSettings { settings in
                    settings.preferredWorkEndHour = max(hour, settings.preferredWorkStartHour + 1)
                }
            }
        )
    }

    private var defaultDurationBinding: Binding<Int> {
        Binding(
            get: { services.localStore.settings.defaultTaskDurationMinutes },
            set: { minutes in
                services.localStore.updateSettings { settings in
                    settings.defaultTaskDurationMinutes = minutes
                }
            }
        )
    }

    private func hourLabel(_ hour: Int) -> String {
        let normalizedHour = ((hour % 24) + 24) % 24
        let suffix = normalizedHour < 12 ? "AM" : "PM"
        let displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12
        return "\(displayHour):00 \(suffix)"
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
