import SwiftUI

struct ReminderDecisionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices

    let taskID: UUID

    @State private var isShowingDeleteConfirmation = false
    @State private var shrinkDismissed = false
    @State private var isShowingRescheduleSheet = false
    @State private var isShowingBreakdownSheet = false

    private var task: DLTask? {
        services.localStore.task(id: taskID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DLSpacing.xl) {
            if let task {
                header(task)
                decisionGrid(task)

                if task.shouldOfferShrink && !shrinkDismissed {
                    shrinkPrompt(task)
                }
            } else {
                DLEmptyState(
                    title: "Task unavailable",
                    detail: "This reminder points to a task that is already done or deleted.",
                    systemImage: "bell.slash"
                )
            }
        }
        .padding(DLSpacing.lg)
        .background(DLColor.background)
        .confirmationDialog("Delete this task?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Task", role: .destructive) {
                deleteTask()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the task from active DoneLoop views and cancels its reminder.")
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
        VStack(alignment: .leading, spacing: DLSpacing.sm) {
            Text(task.title.nonEmpty ?? "Untitled task")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DLColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(task.nextAction.nonEmpty ?? task.summary.nonEmpty ?? "Choose what happens next.")
                .font(.callout)
                .foregroundStyle(DLColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DLSpacing.sm) {
                DLStatusBadge(status: task.status == .blocked ? .blocked : .needsDecision)
                Text("Snoozed \(task.snoozeCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DLColor.info)
                    .padding(.horizontal, DLSpacing.sm)
                    .padding(.vertical, DLSpacing.xs)
                    .background(DLColor.infoMuted, in: Capsule())
            }
        }
    }

    private func decisionGrid(_ task: DLTask) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DLSpacing.md) {
            decisionButton("Done", systemImage: "checkmark.circle.fill", tint: DLColor.success) {
                completeTask(task.id)
                dismiss()
            }

            decisionButton("Snooze", systemImage: "moon.fill", tint: DLColor.info) {
                services.localStore.snoozeTask(id: task.id)
                _ = services.notifications.scheduleReminder(for: task.id, in: services.localStore)
            }

            decisionButton("Reschedule", systemImage: "calendar.badge.clock", tint: DLColor.info) {
                isShowingRescheduleSheet = true
            }

            decisionButton("Break down", systemImage: "list.bullet.indent", tint: DLColor.primary) {
                isShowingBreakdownSheet = true
            }

            decisionButton("Blocked", systemImage: "hand.raised.fill", tint: DLColor.attention) {
                services.notifications.cancelReminder(for: task.id, in: services.localStore)
                services.localStore.updateTaskStatus(id: task.id, status: .blocked)
                dismiss()
            }

            decisionButton("Delete", systemImage: "trash", tint: DLColor.danger) {
                isShowingDeleteConfirmation = true
            }
        }
    }

    private func shrinkPrompt(_ task: DLTask) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            Text("You have avoided this twice. Want a smaller version?")
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)
            Text(shrinkPreview(for: task))
                .font(.callout)
                .foregroundStyle(DLColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DLSpacing.md) {
                Button("Dismiss") {
                    shrinkDismissed = true
                }
                .buttonStyle(.bordered)

                Button("Mark Blocked") {
                    services.notifications.cancelReminder(for: task.id, in: services.localStore)
                    services.localStore.updateTaskStatus(id: task.id, status: .blocked)
                    dismiss()
                }
                .buttonStyle(.bordered)

                DLPrimaryButton("Shrink", systemImage: "arrow.down.right") {
                    isShowingBreakdownSheet = true
                }
            }
        }
        .padding(DLSpacing.md)
        .background(DLColor.attentionMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
    }

    private func decisionButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(tint)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DLRadius.md))
        }
        .buttonStyle(.plain)
    }

    private func deleteTask() {
        if services.localStore.task(id: taskID)?.calendarEventID != nil {
            _ = services.calendar.deleteEvent(for: taskID, in: services.localStore)
        }
        services.notifications.cancelReminder(for: taskID, in: services.localStore)
        services.localStore.deleteTask(id: taskID)
        dismiss()
    }

    private func completeTask(_ taskID: UUID) {
        services.notifications.cancelReminder(for: taskID, in: services.localStore)
        if services.localStore.task(id: taskID)?.calendarEventID != nil {
            _ = services.calendar.deleteEvent(for: taskID, in: services.localStore)
        }
        services.localStore.updateTaskStatus(id: taskID, status: .done)
    }

    private func shrinkPreview(for task: DLTask) -> String {
        if task.title.lowercased().contains("jobs") {
            return "Smaller task: Apply to 1 job. Next action: Open one saved job link."
        }
        if task.title.lowercased().contains("resume") {
            return "Smaller task: Improve one resume section. Next action: Edit one bullet."
        }
        return "Smaller task: Start this task. Next action: Do the first visible two-minute step."
    }
}

private extension DLTask {
    var shouldOfferShrink: Bool {
        snoozeCount >= 2 && status != .blocked && status != .done && status != .deleted
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
