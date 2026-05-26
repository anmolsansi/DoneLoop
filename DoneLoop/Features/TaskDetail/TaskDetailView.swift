import SwiftUI

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices

    let taskID: UUID
    let showDecisionSheet: () -> Void

    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingRescheduleSheet = false
    @State private var isShowingBreakdownSheet = false

    private var task: DLTask? {
        services.localStore.task(id: taskID)
    }

    var body: some View {
        ScrollView {
            if let task {
                VStack(alignment: .leading, spacing: DLSpacing.xl) {
                    header(task)
                    nextAction(task)
                    scheduleDetails(task)
                    statusGrid(task)
                    sourceDetails(task)
                    decisionActions(task)
                }
                .padding(DLSpacing.lg)
            } else {
                DLEmptyState(
                    title: "Task missing",
                    detail: "This task was deleted or is no longer available.",
                    systemImage: "exclamationmark.triangle"
                )
                .padding(DLSpacing.lg)
            }
        }
        .background(DLColor.background)
        .navigationTitle("Task Detail")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .confirmationDialog("Delete this task?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Task", role: .destructive) {
                if services.localStore.task(id: taskID)?.calendarEventID != nil {
                    _ = services.calendar.deleteEvent(for: taskID, in: services.localStore)
                }
                services.notifications.cancelReminder(for: taskID, in: services.localStore)
                services.localStore.deleteTask(id: taskID)
                dismiss()
            }
        } message: {
            Text("This removes the task from active DoneLoop views and cancels its reminder. If a Calendar event exists, DoneLoop will remove or disconnect it.")
        }
        .sheet(isPresented: $isShowingRescheduleSheet) {
            DLRescheduleSheet(taskID: taskID)
                .environmentObject(services)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingBreakdownSheet) {
            DLBreakdownPreviewSheet(taskID: taskID)
                .environmentObject(services)
                .presentationDetents([.large])
        }
    }

    private func header(_ task: DLTask) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            Text(task.title.nonEmpty ?? "Untitled task")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DLColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let summary = task.summary.nonEmpty {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(DLColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: DLSpacing.sm) {
                DLStatusBadge(status: task.displayStatus(settings: services.localStore.settings))
                priorityBadge(task.priority)
            }
        }
    }

    private func nextAction(_ task: DLTask) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.sm) {
            Text("Next Action")
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)
            Text(task.nextAction.nonEmpty ?? "Choose a smaller next action before starting.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DLColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DLSpacing.md)
        .background(DLColor.primaryMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
    }

    private func scheduleDetails(_ task: DLTask) -> some View {
        detailSection(title: "Schedule") {
            detailRow("Due", value: formattedDate(task.dueDate) ?? "Not set", systemImage: "bell")
            detailRow("Due time", value: formattedTime(task.dueTime) ?? "Not set", systemImage: "clock")
            detailRow("Start", value: formattedDateTime(task.scheduledStart) ?? "Not scheduled", systemImage: "calendar")
            detailRow("End", value: formattedDateTime(task.scheduledEnd) ?? "Not scheduled", systemImage: "calendar.badge.clock")
            detailRow("Calendar", value: calendarStatusText(task), systemImage: "calendar.circle")
            detailRow("Reminder", value: reminderStatusText(task), systemImage: "bell")
        }
    }

    private func statusGrid(_ task: DLTask) -> some View {
        detailSection(title: "Task State") {
            detailRow("Status", value: task.status.displayName, systemImage: "checklist")
            detailRow("Category", value: task.category.nonEmpty ?? "None", systemImage: "folder")
            detailRow("Snoozed", value: "\(task.snoozeCount)", systemImage: "moon")
            detailRow("Missed", value: "\(task.missedCount)", systemImage: "exclamationmark.triangle")
            detailRow("Created", value: formattedDateTime(task.createdAt) ?? "Unknown", systemImage: "plus.circle")
            detailRow("Updated", value: formattedDateTime(task.updatedAt) ?? "Unknown", systemImage: "arrow.clockwise")
        }
    }

    private func sourceDetails(_ task: DLTask) -> some View {
        detailSection(title: "Source") {
            if let captureID = task.sourceCaptureID, let capture = services.localStore.capture(id: captureID) {
                detailRow("Capture", value: capture.source.displayName, systemImage: capture.source == .voice ? "mic" : "text.cursor")
                detailRow("Original", value: capture.transcript.nonEmpty ?? capture.rawText.nonEmpty ?? "Empty capture", systemImage: "quote.bubble")
            } else if task.sourceCaptureID != nil {
                detailRow("Capture", value: "Source capture deleted", systemImage: "exclamationmark.triangle")
            } else {
                detailRow("Capture", value: "Local item", systemImage: "tray")
            }
            detailRow("AI provider", value: task.aiProviderUsed.displayName, systemImage: "sparkles")
        }
    }

    private func decisionActions(_ task: DLTask) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            Text("Decision")
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DLSpacing.sm) {
                decisionButton("Done", systemImage: "checkmark.circle.fill", tint: DLColor.success) {
                    completeTask(task.id)
                    dismiss()
                }
                decisionButton("Snooze 30m", systemImage: "moon.fill", tint: DLColor.info) {
                    services.localStore.snoozeTask(id: task.id)
                    _ = services.notifications.scheduleReminder(for: task.id, in: services.localStore)
                }
                decisionButton("Reschedule", systemImage: "calendar.badge.clock", tint: DLColor.info) {
                    isShowingRescheduleSheet = true
                }
                decisionButton("Break down", systemImage: "arrow.down.right.and.arrow.up.left", tint: DLColor.primary) {
                    isShowingBreakdownSheet = true
                }
                decisionButton("Blocked", systemImage: "hand.raised.fill", tint: DLColor.attention) {
                    services.notifications.cancelReminder(for: task.id, in: services.localStore)
                    services.localStore.updateTaskStatus(id: task.id, status: .blocked)
                }
                decisionButton("Decision Sheet", systemImage: "checklist", tint: DLColor.primary) {
                    showDecisionSheet()
                }
            }

            if task.snoozeCount >= 2 && task.status != .blocked {
                VStack(alignment: .leading, spacing: DLSpacing.sm) {
                    Text("You have avoided this twice. Want a smaller version?")
                        .font(.headline)
                        .foregroundStyle(DLColor.textPrimary)
                    Text("Break down keeps the original task local and replaces it with the smallest clear next action.")
                        .font(.callout)
                        .foregroundStyle(DLColor.textSecondary)
                    DLPrimaryButton("Shrink Task", systemImage: "arrow.down.right") {
                        isShowingBreakdownSheet = true
                    }
                }
                .padding(DLSpacing.md)
                .background(DLColor.attentionMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
            }

            if task.calendarSyncStatus == .failed || task.calendarSyncStatus == .disconnected || task.calendarEventID == nil && task.scheduledStart != nil {
                Button {
                    _ = services.calendar.updateEvent(for: task.id, in: services.localStore)
                } label: {
                    Label("Retry Calendar Sync", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DLSpacing.md)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DLSpacing.md)
            }
            .buttonStyle(.bordered)
        }
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)
            content()
        }
        .padding(DLSpacing.md)
        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DLRadius.md)
                .stroke(DLColor.divider, lineWidth: 0.5)
        )
    }

    private func detailRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: DLSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(DLColor.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: DLSpacing.xs) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DLColor.textTertiary)
                Text(value)
                    .font(.callout)
                    .foregroundStyle(DLColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private func decisionButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DLSpacing.md)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DLRadius.md))
    }

    private func completeTask(_ taskID: UUID) {
        services.notifications.cancelReminder(for: taskID, in: services.localStore)
        if services.localStore.task(id: taskID)?.calendarEventID != nil {
            _ = services.calendar.deleteEvent(for: taskID, in: services.localStore)
        }
        services.localStore.updateTaskStatus(id: taskID, status: .done)
    }

    private func priorityBadge(_ priority: DLTaskPriority) -> some View {
        Text(priority.displayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DLColor.info)
            .padding(.horizontal, DLSpacing.sm)
            .padding(.vertical, DLSpacing.xs)
            .background(DLColor.infoMuted, in: Capsule())
    }

    private func calendarStatusText(_ task: DLTask) -> String {
        if task.calendarSyncStatus == .failed {
            return task.calendarSyncError ?? "Sync failed"
        }
        if task.calendarSyncStatus == .disconnected {
            return "Calendar disconnected"
        }
        if task.calendarEventID != nil || task.calendarSyncStatus == .synced {
            return "Synced"
        }
        if task.scheduledStart != nil {
            return services.localStore.settings.googleCalendarID == nil ? "Disconnected" : "Calendar pending"
        }
        return "Not scheduled"
    }

    private func reminderStatusText(_ task: DLTask) -> String {
        if let error = task.notificationError.nonEmpty {
            return error
        }
        if task.notificationStatus == .scheduled, let date = task.scheduledStart ?? task.dueDate ?? task.dueTime {
            return "Scheduled for \(date.formatted(date: .abbreviated, time: .shortened))"
        }
        if services.localStore.settings.notificationPermissionStatus == .denied {
            return "Notification permission denied"
        }
        return task.notificationStatus.displayName
    }

    private func formattedDate(_ date: Date?) -> String? {
        date?.formatted(date: .abbreviated, time: .omitted)
    }

    private func formattedTime(_ date: Date?) -> String? {
        date?.formatted(date: .omitted, time: .shortened)
    }

    private func formattedDateTime(_ date: Date?) -> String? {
        date?.formatted(date: .abbreviated, time: .shortened)
    }
}

struct DLRescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices

    let taskID: UUID

    @State private var selectedStart = Date().addingTimeInterval(30 * 60)
    @State private var durationMinutes = 30
    @State private var errorMessage: String?

    private var task: DLTask? {
        services.localStore.task(id: taskID)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DLSpacing.xl) {
                if let task {
                    VStack(alignment: .leading, spacing: DLSpacing.sm) {
                        Text(task.title.nonEmpty ?? "Untitled task")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(DLColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Pick a new time. DoneLoop will update the task, reminder, and Calendar status together.")
                            .font(.callout)
                            .foregroundStyle(DLColor.textSecondary)
                    }

                    quickChoices

                    VStack(alignment: .leading, spacing: DLSpacing.md) {
                        DatePicker("Start", selection: $selectedStart, displayedComponents: [.date, .hourAndMinute])
                        Stepper(value: $durationMinutes, in: 5...180, step: 5) {
                            Text("Duration: \(durationMinutes) minutes")
                        }
                    }
                    .padding(DLSpacing.md)
                    .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(DLColor.danger)
                            .padding(DLSpacing.md)
                            .background(DLColor.dangerMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
                    }

                    DLPrimaryButton("Save Reschedule", systemImage: "calendar.badge.clock") {
                        save()
                    }
                } else {
                    DLEmptyState(
                        title: "Task unavailable",
                        detail: "This task was deleted before it could be rescheduled.",
                        systemImage: "calendar.badge.exclamationmark"
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(DLSpacing.lg)
            .background(DLColor.background)
            .navigationTitle("Reschedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    private var quickChoices: some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            Text("Quick Choices")
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DLSpacing.sm) {
                quickChoiceButton("Later today", systemImage: "clock") {
                    selectedStart = nextWorkingTime(hoursFromNow: 2)
                }
                quickChoiceButton("Tomorrow AM", systemImage: "sunrise") {
                    selectedStart = nextDay(hour: services.localStore.settings.preferredWorkStartHour)
                }
                quickChoiceButton("Tomorrow PM", systemImage: "sunset") {
                    selectedStart = nextDay(hour: max(services.localStore.settings.preferredWorkEndHour - 2, services.localStore.settings.preferredWorkStartHour))
                }
                quickChoiceButton("Next workday", systemImage: "calendar") {
                    selectedStart = nextWorkday()
                }
            }
        }
    }

    private func quickChoiceButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DLSpacing.md)
                .foregroundStyle(DLColor.primary)
                .background(DLColor.primaryMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
        }
        .buttonStyle(.plain)
    }

    private func loadInitialValues() {
        guard let task else { return }
        selectedStart = task.scheduledStart ?? task.dueDate ?? Date().addingTimeInterval(30 * 60)
        if let start = task.scheduledStart, let end = task.scheduledEnd {
            durationMinutes = max(5, Int(end.timeIntervalSince(start) / 60))
        } else {
            durationMinutes = services.localStore.settings.defaultTaskDurationMinutes
        }
    }

    private func save() {
        guard selectedStart > Date() else {
            errorMessage = "Choose a future time."
            return
        }

        errorMessage = nil
        services.notifications.cancelReminder(for: taskID, in: services.localStore)
        services.localStore.rescheduleTask(id: taskID, start: selectedStart, durationMinutes: durationMinutes)
        _ = services.calendar.updateEvent(for: taskID, in: services.localStore)
        _ = services.notifications.scheduleReminder(for: taskID, in: services.localStore)
        dismiss()
    }

    private func nextWorkingTime(hoursFromNow: Int) -> Date {
        let proposed = Date().addingTimeInterval(TimeInterval(hoursFromNow * 60 * 60))
        return proposed > Date() ? proposed : Date().addingTimeInterval(30 * 60)
    }

    private func nextDay(hour: Int) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(24 * 60 * 60)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func nextWorkday() -> Date {
        var date = nextDay(hour: services.localStore.settings.preferredWorkStartHour)
        let calendar = Calendar.current
        while calendar.isDateInWeekend(date) {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(24 * 60 * 60)
        }
        return date
    }
}

struct DLBreakdownPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices

    let taskID: UUID

    @State private var selectedSuggestion: DLBreakdownSuggestion?
    @State private var editedTitle = ""
    @State private var editedSummary = ""
    @State private var editedNextAction = ""

    private var task: DLTask? {
        services.localStore.task(id: taskID)
    }

    private var suggestions: [DLBreakdownSuggestion] {
        services.localStore.breakdownSuggestions(for: taskID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DLSpacing.xl) {
                    if let task {
                        VStack(alignment: .leading, spacing: DLSpacing.sm) {
                            Text("Break Down")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(DLColor.textPrimary)
                            Text(task.title.nonEmpty ?? "Untitled task")
                                .font(.headline)
                                .foregroundStyle(DLColor.textPrimary)
                            Text("Preview a smaller version before changing the task.")
                                .font(.callout)
                                .foregroundStyle(DLColor.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: DLSpacing.md) {
                            Text("Suggested Smaller Tasks")
                                .font(.headline)
                                .foregroundStyle(DLColor.textPrimary)

                            if suggestions.isEmpty {
                                quietEmptyRow("No suggestion is available for this task yet.")
                            } else {
                                ForEach(suggestions) { suggestion in
                                    suggestionButton(suggestion)
                                }
                            }
                        }

                        editSection

                        DLPrimaryButton("Apply Smaller Task", systemImage: "checkmark.circle") {
                            apply()
                        }
                        .disabled(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        DLEmptyState(
                            title: "Task unavailable",
                            detail: "This task was deleted before it could be broken down.",
                            systemImage: "list.bullet.rectangle"
                        )
                    }
                }
                .padding(DLSpacing.lg)
            }
            .background(DLColor.background)
            .navigationTitle("Break Down")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: selectInitialSuggestion)
        }
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            Text("Edit Before Applying")
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)
            TextField("Smaller task", text: $editedTitle, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            TextField("Summary", text: $editedSummary, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            TextField("Next action", text: $editedNextAction, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
        .padding(DLSpacing.md)
        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
    }

    private func suggestionButton(_ suggestion: DLBreakdownSuggestion) -> some View {
        Button {
            select(suggestion)
        } label: {
            HStack(alignment: .top, spacing: DLSpacing.md) {
                Image(systemName: selectedSuggestion?.id == suggestion.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(DLColor.primary)
                VStack(alignment: .leading, spacing: DLSpacing.xs) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundStyle(DLColor.textPrimary)
                    Text(suggestion.nextAction)
                        .font(.callout)
                        .foregroundStyle(DLColor.textSecondary)
                }
                Spacer()
            }
            .padding(DLSpacing.md)
            .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DLRadius.md)
                    .stroke(selectedSuggestion?.id == suggestion.id ? DLColor.primary : DLColor.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func quietEmptyRow(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DLSpacing.md)
            .background(DLColor.surfaceMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
    }

    private func selectInitialSuggestion() {
        guard selectedSuggestion == nil else { return }
        if let suggestion = suggestions.first {
            select(suggestion)
        } else if let task {
            select(DLBreakdownSuggestion.fallback(for: task))
        }
    }

    private func select(_ suggestion: DLBreakdownSuggestion) {
        selectedSuggestion = suggestion
        editedTitle = suggestion.title
        editedSummary = suggestion.summary
        editedNextAction = suggestion.nextAction
    }

    private func apply() {
        let suggestion = DLBreakdownSuggestion(
            title: editedTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: editedSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            nextAction: editedNextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        _ = services.localStore.applyBreakdownSuggestion(id: taskID, suggestion: suggestion)
        dismiss()
    }
}

private extension DLTask {
    func displayStatus(settings: DLUserSettings) -> DLStatus {
        switch status {
        case .done:
            return .done
        case .blocked:
            return .blocked
        case .inbox:
            return .needsDecision
        case .scheduled, .inProgress, .snoozed:
            if calendarSyncStatus == .failed {
                return .calendarFailed
            }
            if calendarSyncStatus == .disconnected {
                return .calendarDisconnected
            }
            if calendarEventID != nil || calendarSyncStatus == .synced {
                return .calendarSynced
            }
            if scheduledStart != nil {
                return settings.googleCalendarID == nil ? .calendarDisconnected : .calendarPending
            }
            return .notScheduled
        case .deleted:
            return .notScheduled
        }
    }
}

private extension DLTaskStatus {
    var displayName: String {
        switch self {
        case .inbox: "Inbox"
        case .scheduled: "Scheduled"
        case .inProgress: "In Progress"
        case .done: "Done"
        case .snoozed: "Snoozed"
        case .blocked: "Blocked"
        case .deleted: "Deleted"
        }
    }
}

private extension DLTaskPriority {
    var displayName: String {
        switch self {
        case .low: "Low priority"
        case .normal: "Normal priority"
        case .high: "High priority"
        }
    }
}

private extension DLAIProvider {
    var displayName: String {
        switch self {
        case .none: "None"
        case .local: "Local"
        case .ruleBased: "Rule-based"
        case .cloudFallback: "Cloud fallback"
        }
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension DLCaptureSource {
    var displayName: String {
        switch self {
        case .voice: "Voice"
        case .text: "Text"
        }
    }
}
