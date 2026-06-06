import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var isShowingGoogleConnectFlow = false
    @State private var isShowingResetConfirmation = false
    @State private var isShowingAccountSheet = false
    @State private var isShowingCalendarConfigSheet = false

    var body: some View {
        List {
            Section("Account") {
                if let session = services.auth.session {
                    settingsRow(
                        title: session.email,
                        detail: "Signed in locally. Session is stored in Keychain.",
                        symbol: "person.crop.circle.badge.checkmark",
                        status: .calendarSynced
                    )
                    Button {
                        services.auth.logOut()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) {
                        services.auth.deleteLocalAccount()
                    } label: {
                        Label("Delete Local Account", systemImage: "trash")
                    }
                } else {
                    settingsRow(
                        title: "No account",
                        detail: "Local-only use still works. Sign up when you want a protected local session.",
                        symbol: "person.crop.circle",
                        status: .needsDecision
                    )
                    Button {
                        isShowingAccountSheet = true
                    } label: {
                        Label("Sign Up or Log In", systemImage: "person.badge.key")
                    }
                }
            }

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
                        Label("Connect Google Calendar", systemImage: "calendar.badge.plus")
                    }
                }

                Button {
                    isShowingCalendarConfigSheet = true
                } label: {
                    Label("OAuth Configuration", systemImage: "key")
                }

                if services.calendar.isConnecting {
                    ProgressView("Connecting...")
                }

                if let message = services.calendar.lastConnectionMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(DLColor.textSecondary)
                }
            }

            Section("AI Permissions") {
                Toggle("Allow local AI assistance", isOn: aiAssistanceConsentBinding)
                settingsRow(
                    title: services.localStore.settings.aiAssistanceConsentGranted ? "AI assistance allowed" : "AI assistance off",
                    detail: "When allowed, DoneLoop can classify messy captures and suggest smaller task breakdowns locally.",
                    symbol: "sparkles",
                    status: services.localStore.settings.aiAssistanceConsentGranted ? .calendarSynced : .needsDecision
                )

                Toggle("Allow cloud fallback later", isOn: cloudAIConsentBinding)
                settingsRow(
                    title: services.localStore.settings.cloudAIConsentGranted ? "Cloud fallback allowed" : "Cloud fallback blocked",
                    detail: "No cloud AI is called in this build. This records explicit consent for future provider setup.",
                    symbol: "cloud",
                    status: services.localStore.settings.cloudAIConsentGranted ? .calendarSynced : .notScheduled
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
                    title: "Secure storage",
                    detail: "Account sessions and Google tokens are stored in Keychain.",
                    symbol: "key.fill",
                    status: .calendarSynced
                )
                settingsRow(
                    title: "No backend required",
                    detail: "V1 local account mode does not require a DoneLoop server.",
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
            Button("Start OAuth") {
                services.calendar.connect(store: services.localStore)
            }
            Button("Configure OAuth") {
                isShowingCalendarConfigSheet = true
            }
            Button("Deny Permission", role: .destructive) {
                services.calendar.simulatePermissionDenied(store: services.localStore)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Google Calendar uses OAuth with PKCE. Enter an iOS OAuth client ID and redirect scheme before connecting.")
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
        .sheet(isPresented: $isShowingAccountSheet) {
            AccountAuthSheet()
                .environmentObject(services)
        }
        .sheet(isPresented: $isShowingCalendarConfigSheet) {
            GoogleCalendarOAuthConfigSheet()
                .environmentObject(services)
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

    private var aiAssistanceConsentBinding: Binding<Bool> {
        Binding(
            get: { services.localStore.settings.aiAssistanceConsentGranted },
            set: { consent in
                services.localStore.updateSettings { settings in
                    settings.aiAssistanceConsentGranted = consent
                }
            }
        )
    }

    private var cloudAIConsentBinding: Binding<Bool> {
        Binding(
            get: { services.localStore.settings.cloudAIConsentGranted },
            set: { consent in
                services.localStore.updateSettings { settings in
                    settings.cloudAIConsentGranted = consent
                    if !consent && settings.aiMode == .localWithFallback {
                        settings.aiMode = .localOnly
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

private struct AccountAuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices
    @State private var mode: Mode = .signUp
    @State private var email = ""
    @State private var password = ""

    enum Mode: String, CaseIterable {
        case signUp = "Sign Up"
        case logIn = "Log In"
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Section("Account") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                    Text("This creates a local account and stores the session securely in Keychain. It does not create a cloud account.")
                        .font(.caption)
                        .foregroundStyle(DLColor.textSecondary)
                }

                if let error = services.auth.lastErrorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(DLColor.danger)
                    }
                }

                Section {
                    DLPrimaryButton(mode.rawValue, systemImage: "person.badge.key") {
                        switch mode {
                        case .signUp:
                            services.auth.signUp(email: email, password: password)
                        case .logIn:
                            services.auth.logIn(email: email, password: password)
                        }
                        if services.auth.isSignedIn {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(mode.rawValue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct GoogleCalendarOAuthConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices
    @State private var clientID = ""
    @State private var redirectScheme = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("OAuth") {
                    TextField("iOS OAuth client ID", text: $clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Redirect scheme", text: $redirectScheme)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Use the custom URL scheme registered for the iOS OAuth client. Tokens are stored in Keychain; the client ID and scheme are saved as non-secret settings.")
                        .font(.caption)
                        .foregroundStyle(DLColor.textSecondary)
                }

                Section {
                    DLPrimaryButton("Save OAuth Config", systemImage: "key") {
                        services.calendar.saveOAuthConfiguration(
                            clientID: clientID,
                            redirectScheme: redirectScheme,
                            store: services.localStore
                        )
                        dismiss()
                    }
                }
            }
            .navigationTitle("Google OAuth")
            .onAppear {
                let settings = services.localStore.settings
                clientID = settings.googleOAuthClientID ?? ""
                redirectScheme = settings.googleOAuthRedirectScheme ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
