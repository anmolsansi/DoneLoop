import SwiftUI

struct TaskDetailPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices

    let taskID: UUID
    let showDecisionSheet: () -> Void

    @State private var isShowingDeleteConfirmation = false

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
            Text("This removes the task from active DoneLoop views. Calendar cleanup is handled by the later calendar sync ticket.")
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
                    services.notifications.cancelReminder(for: task.id, in: services.localStore)
                    services.localStore.updateTaskStatus(id: task.id, status: .done)
                    dismiss()
                }
                decisionButton("Snooze 30m", systemImage: "moon.fill", tint: DLColor.info) {
                    services.localStore.snoozeTask(id: task.id)
                    _ = services.notifications.scheduleReminder(for: task.id, in: services.localStore)
                }
                decisionButton("Reschedule", systemImage: "calendar.badge.clock", tint: DLColor.info) {
                    services.localStore.rescheduleTask(
                        id: task.id,
                        start: Date().addingTimeInterval(30 * 60),
                        durationMinutes: services.localStore.settings.defaultTaskDurationMinutes
                    )
                    _ = services.calendar.updateEvent(for: task.id, in: services.localStore)
                    _ = services.notifications.scheduleReminder(for: task.id, in: services.localStore)
                }
                decisionButton("Break down", systemImage: "arrow.down.right.and.arrow.up.left", tint: DLColor.primary) {
                    _ = services.localStore.shrinkTask(id: task.id)
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
                        _ = services.localStore.shrinkTask(id: task.id)
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
