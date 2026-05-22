import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var services: AppServices
    let showTaskDetail: (UUID) -> Void

    private var unscheduledTasks: [DLTask] {
        services.localStore.tasks
            .filter { $0.status == .inbox && $0.scheduledStart == nil && $0.dueDate == nil }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var needsClarificationTasks: [DLTask] {
        unscheduledTasks.filter { $0.nextAction == nil || $0.nextAction?.isEmptyOrWhitespace == true }
    }

    private var clearUnscheduledTasks: [DLTask] {
        unscheduledTasks.filter { task in
            !needsClarificationTasks.contains { $0.id == task.id }
        }
    }

    private var notes: [DLNote] {
        services.localStore.notes
            .filter { $0.category != "brain_dump" }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var brainDumps: [DLNote] {
        services.localStore.notes
            .filter { $0.category == "brain_dump" }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var ideas: [DLIdea] {
        services.localStore.ideas
            .filter { $0.convertedToTaskID == nil }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var isEmpty: Bool {
        unscheduledTasks.isEmpty && notes.isEmpty && ideas.isEmpty && brainDumps.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DLSpacing.xl) {
                header

                if isEmpty {
                    DLEmptyState(
                        title: "Inbox is clear",
                        detail: "Unscheduled tasks, notes, ideas, and brain dumps will wait here until you decide what to do.",
                        systemImage: "tray"
                    )
                } else {
                    taskSection(
                        title: "Needs Clarification",
                        detail: "Vague tasks stay here until they are scheduled, blocked, broken down, or deleted.",
                        tasks: needsClarificationTasks,
                        emptyText: "No unclear tasks."
                    )

                    taskSection(
                        title: "Unscheduled Tasks",
                        detail: "Captured work that does not belong on the calendar yet.",
                        tasks: clearUnscheduledTasks,
                        emptyText: "No unscheduled tasks."
                    )

                    noteSection(title: "Notes", detail: "Reference items that do not require a decision.", notes: notes)
                    ideaSection
                    noteSection(title: "Brain Dumps", detail: "Messy captures saved for later cleanup.", notes: brainDumps)
                }
            }
            .padding(DLSpacing.lg)
        }
        .background(DLColor.background)
        .navigationTitle("Inbox")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DLSpacing.xs) {
            Text("Inbox")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DLColor.textPrimary)
            Text("Hold unclear work here until it has a next decision.")
                .font(.callout)
                .foregroundStyle(DLColor.textSecondary)
        }
    }

    private func taskSection(title: String, detail: String, tasks: [DLTask], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            sectionHeader(title: title, detail: detail)

            if tasks.isEmpty {
                quietEmptyRow(emptyText)
            } else {
                ForEach(tasks) { task in
                    inboxTaskCard(task)
                }
            }
        }
    }

    private func inboxTaskCard(_ task: DLTask) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            Button(action: { showTaskDetail(task.id) }) {
                HStack(alignment: .top, spacing: DLSpacing.md) {
                    VStack(alignment: .leading, spacing: DLSpacing.xs) {
                        Text(task.title.nonEmpty ?? "Untitled task")
                            .font(.headline)
                            .foregroundStyle(DLColor.textPrimary)
                            .lineLimit(2)
                        Text(task.nextAction.nonEmpty ?? "When do you want to work on this?")
                            .font(.callout)
                            .foregroundStyle(DLColor.textSecondary)
                            .lineLimit(2)
                        Text(sourceText(for: task))
                            .font(.caption)
                            .foregroundStyle(DLColor.textTertiary)
                    }
                    Spacer(minLength: DLSpacing.sm)
                    DLStatusBadge(status: .needsDecision)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: DLSpacing.sm) {
                quickAction("Schedule", systemImage: "calendar.badge.plus") {
                    services.localStore.updateTaskStatus(id: task.id, status: .scheduled)
                    _ = services.calendar.updateEvent(for: task.id, in: services.localStore)
                    _ = services.notifications.scheduleReminder(for: task.id, in: services.localStore)
                }
                quickAction("Break down", systemImage: "arrow.down.right.and.arrow.up.left") {
                    _ = services.localStore.shrinkTask(id: task.id)
                }
                quickAction("Blocked", systemImage: "hand.raised") {
                    services.notifications.cancelReminder(for: task.id, in: services.localStore)
                    services.localStore.updateTaskStatus(id: task.id, status: .blocked)
                }
                Button(role: .destructive) {
                    services.notifications.cancelReminder(for: task.id, in: services.localStore)
                    services.localStore.deleteTask(id: task.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Delete task")
            }
        }
        .padding(DLSpacing.md)
        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DLRadius.md)
                .stroke(DLColor.divider, lineWidth: 0.5)
        )
    }

    private func noteSection(title: String, detail: String, notes: [DLNote]) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            sectionHeader(title: title, detail: detail)

            if notes.isEmpty {
                quietEmptyRow("Nothing here yet.")
            } else {
                ForEach(notes) { note in
                    referenceCard(
                        title: note.title.nonEmpty ?? "Untitled note",
                        detail: note.summary.nonEmpty ?? note.content,
                        source: sourceText(sourceCaptureID: note.sourceCaptureID),
                        systemImage: note.category == "brain_dump" ? "tray.full" : "note.text"
                    )
                }
            }
        }
    }

    private var ideaSection: some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            sectionHeader(title: "Ideas", detail: "Possible future tasks that have not been converted.")

            if ideas.isEmpty {
                quietEmptyRow("No ideas waiting.")
            } else {
                ForEach(ideas) { idea in
                    referenceCard(
                        title: idea.title.nonEmpty ?? "Untitled idea",
                        detail: idea.suggestedNextAction.nonEmpty ?? idea.summary.nonEmpty ?? "No suggested next action yet.",
                        source: "Idea",
                        systemImage: "lightbulb"
                    )
                }
            }
        }
    }

    private func referenceCard(title: String, detail: String, source: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: DLSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(DLColor.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: DLSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DLColor.textPrimary)
                    .lineLimit(2)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(DLColor.textSecondary)
                    .lineLimit(3)
                Text(source)
                    .font(.caption)
                    .foregroundStyle(DLColor.textTertiary)
            }
            Spacer()
        }
        .padding(DLSpacing.md)
        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DLRadius.md)
                .stroke(DLColor.divider, lineWidth: 0.5)
        )
    }

    private func sectionHeader(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(DLColor.textSecondary)
        }
    }

    private func quietEmptyRow(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DLSpacing.md)
            .background(DLColor.surfaceMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
    }

    private func quickAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }

    private func sourceText(for task: DLTask) -> String {
        sourceText(sourceCaptureID: task.sourceCaptureID)
    }

    private func sourceText(sourceCaptureID: UUID?) -> String {
        guard let sourceCaptureID else { return "Local item" }
        guard let capture = services.localStore.capture(id: sourceCaptureID) else { return "Source capture deleted" }
        return "\(capture.source.displayName) capture"
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

    var isEmptyOrWhitespace: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
