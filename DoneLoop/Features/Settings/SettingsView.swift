import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var isShowingGoogleConnectFlow = false
    @State private var isShowingResetConfirmation = false

    var body: some View {
        List {
            Section("Google Calendar") {
                settingsRow(
                    title: "Connection",
                    detail: calendarConnectionDetail,
                    symbol: calendarConnectionSymbol,
                    status: calendarConnectionStatus
                )

                if services.calendar.isConnected(settings: services.localStore.settings) {
                    Button(role: .destructive) {
                        services.calendar.disconnect(store: services.localStore)
                    } label: {
                        Label("Disconnect Google Calendar", systemImage: "xmark.circle")
                    }
                } else {
                    Button {
                        isShowingGoogleConnectFlow = true
                    } label: {
                        Label("Review Google Calendar Sync", systemImage: "calendar.badge.plus")
                    }
                }
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
                settingsRow(
                    title: "Permission",
                    detail: services.localStore.settings.notificationPermissionStatus.displayName,
                    symbol: reminderPermissionSymbol,
                    status: reminderPermissionStatus
                )
                Stepper(value: defaultSnoozeBinding, in: 5...180, step: 5) {
                    settingsRow(
                        title: "Default snooze",
                        detail: "\(services.localStore.settings.defaultSnoozeMinutes) minutes",
                        symbol: "moon",
                        status: .notScheduled
                    )
                }
                Button {
                    services.notifications.requestPermission(store: services.localStore)
                } label: {
                    Label("Request Notification Permission", systemImage: "bell.badge")
                }
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

            Section("Local QA") {
                settingsRow(
                    title: "Local store",
                    detail: services.localStore.storePath,
                    symbol: "externaldrive",
                    status: .notScheduled
                )
                settingsRow(
                    title: "Items",
                    detail: "\(services.localStore.tasks.count) tasks, \(services.localStore.notes.count) notes, \(services.localStore.ideas.count) ideas, \(services.localStore.captures.count) captures",
                    symbol: "list.bullet.rectangle",
                    status: .notScheduled
                )
                settingsRow(
                    title: "Notifications",
                    detail: services.localStore.settings.notificationPermissionStatus.displayName,
                    symbol: reminderPermissionSymbol,
                    status: reminderPermissionStatus
                )
                settingsRow(
                    title: "Calendar",
                    detail: services.localStore.settings.googleCalendarConnectionStatus.displayName,
                    symbol: calendarConnectionSymbol,
                    status: calendarConnectionStatus
                )
                disclosureText(title: "Last parser output", detail: services.localStore.latestParserOutputPreview)

                Button {
                    services.localStore.resetOnboarding()
                } label: {
                    Label("Show Onboarding Again", systemImage: "arrow.counterclockwise")
                }

                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Label("Reset Local Data", systemImage: "trash")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DLColor.background)
        .navigationTitle("Settings")
        .confirmationDialog("Google Calendar sync", isPresented: $isShowingGoogleConnectFlow, titleVisibility: .visible) {
            Button("Keep Local For Now") {
                services.calendar.connect(store: services.localStore)
            }
            Button("Deny Permission", role: .destructive) {
                services.calendar.simulatePermissionDenied(store: services.localStore)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Real Google OAuth and Calendar event sync are not available in this build. Scheduled work will stay local until a real Google sign-in flow is added.")
        }
        .confirmationDialog("Reset local DoneLoop data?", isPresented: $isShowingResetConfirmation, titleVisibility: .visible) {
            Button("Reset Local Data", role: .destructive) {
                services.notifications.cancelAllReminders(in: services.localStore)
                services.localStore.resetLocalData(keepOnboardingCompleted: true)
                services.notifications.refreshAuthorizationStatus(store: services.localStore)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears local tasks, captures, notes, ideas, settings, and pending reminders on this device.")
        }
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
                if enabled {
                    services.notifications.requestPermission(store: services.localStore)
                } else {
                    services.localStore.updateSettings { settings in
                        settings.remindersEnabled = false
                    }
                    for task in services.localStore.tasks {
                        services.notifications.cancelReminder(for: task.id, in: services.localStore)
                    }
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

    private var defaultSnoozeBinding: Binding<Int> {
        Binding(
            get: { services.localStore.settings.defaultSnoozeMinutes },
            set: { minutes in
                services.localStore.updateSettings { settings in
                    settings.defaultSnoozeMinutes = minutes
                }
            }
        )
    }

    private var calendarConnectionDetail: String {
        let settings = services.localStore.settings
        switch settings.googleCalendarConnectionStatus {
        case .connected:
            let account = settings.googleCalendarAccountEmail ?? "Google account"
            let calendar = settings.googleCalendarName ?? settings.googleCalendarID ?? "Primary Calendar"
            return "\(account) - \(calendar)"
        case .developmentPlaceholder:
            return "Real Google Calendar sync is not available yet. Scheduled work stays local."
        case .disconnected:
            return "Connect before syncing scheduled work."
        case .permissionDenied:
            return "Calendar permission was denied. Reconnect to try again."
        case .tokenExpired:
            return "Google access expired. Reconnect to continue syncing."
        case .networkUnavailable:
            return "Network unavailable. Local tasks will still save."
        }
    }

    private var calendarConnectionSymbol: String {
        switch services.localStore.settings.googleCalendarConnectionStatus {
        case .connected: "calendar.badge.checkmark"
        case .developmentPlaceholder: "calendar.badge.exclamationmark"
        case .disconnected: "calendar.badge.exclamationmark"
        case .permissionDenied: "hand.raised"
        case .tokenExpired: "arrow.clockwise"
        case .networkUnavailable: "wifi.exclamationmark"
        }
    }

    private var calendarConnectionStatus: DLStatus {
        switch services.localStore.settings.googleCalendarConnectionStatus {
        case .connected: .calendarSynced
        case .developmentPlaceholder, .disconnected: .calendarDisconnected
        case .permissionDenied, .tokenExpired, .networkUnavailable: .calendarFailed
        }
    }

    private var reminderPermissionSymbol: String {
        switch services.localStore.settings.notificationPermissionStatus {
        case .notDetermined: "bell"
        case .granted, .provisional: "bell.badge"
        case .denied: "bell.slash"
        }
    }

    private var reminderPermissionStatus: DLStatus {
        switch services.localStore.settings.notificationPermissionStatus {
        case .granted, .provisional: .calendarSynced
        case .notDetermined: .needsDecision
        case .denied: .calendarFailed
        }
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

    private func disclosureText(title: String, detail: String) -> some View {
        DisclosureGroup {
            Text(detail)
                .font(.caption)
                .foregroundStyle(DLColor.textSecondary)
                .textSelection(.enabled)
                .padding(.vertical, DLSpacing.xs)
        } label: {
            Label(title, systemImage: "curlybraces")
                .foregroundStyle(DLColor.textPrimary)
        }
    }
}
