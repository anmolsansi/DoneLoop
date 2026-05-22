import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var services: AppServices
    let showTaskDetail: (UUID) -> Void
    let showCapture: () -> Void

    private var todayTasks: [DLTask] {
        Array(filteredTasks.prefix(3))
    }

    private var calendarBlocks: [DLTask] {
        services.localStore.tasks
            .filter { task in
                task.isActive && task.scheduledStart != nil && Calendar.current.isDateInToday(task.scheduledStart ?? Date.distantPast)
            }
            .sorted { ($0.scheduledStart ?? .distantFuture) < ($1.scheduledStart ?? .distantFuture) }
    }

    private var overdueTasks: [DLTask] {
        let now = Date()
        return services.localStore.tasks
            .filter { task in
                task.isActive && task.isOverdue(referenceDate: now)
            }
            .sorted { $0.sortDate < $1.sortDate }
    }

    private var pendingDecisionTasks: [DLTask] {
        services.localStore.tasks
            .filter { task in
                task.status == .inbox || task.status == .blocked || task.status == .snoozed
            }
            .filter(\.isActive)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
            .map { $0 }
    }

    private var filteredTasks: [DLTask] {
        services.localStore.tasks
            .filter { task in
                task.isActive && !task.isCalendarBlock && task.belongsOnToday
            }
            .sorted(by: deterministicTopTaskSort)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DLSpacing.xl) {
                header

                if todayTasks.isEmpty && calendarBlocks.isEmpty && overdueTasks.isEmpty && pendingDecisionTasks.isEmpty {
                    DLEmptyState(
                        title: "Today is clear",
                        detail: "Capture a thought or open Inbox to choose what deserves attention.",
                        systemImage: "sun.max"
                    )
                } else {
                    section(title: "Top 3", detail: "Only the work that needs a decision today.") {
                        if todayTasks.isEmpty {
                            quietEmptyRow("No top tasks yet.")
                        } else {
                            ForEach(todayTasks) { task in
                                taskButton(task)
                            }
                        }
                    }

                    section(title: "Calendar Blocks", detail: "Local scheduled work. Google Calendar sync comes later.") {
                        if calendarBlocks.isEmpty {
                            quietEmptyRow("No scheduled blocks today.")
                        } else {
                            ForEach(calendarBlocks) { task in
                                calendarBlockRow(task)
                            }
                        }
                    }

                    if !overdueTasks.isEmpty {
                        section(title: "Overdue", detail: "These need a new decision.") {
                            ForEach(overdueTasks.prefix(3)) { task in
                                taskButton(task, statusOverride: .overdue)
                            }
                        }
                    }

                    section(title: "Pending Decisions", detail: "Inbox, snoozed, and blocked work that needs a choice.") {
                        if pendingDecisionTasks.isEmpty {
                            quietEmptyRow("No pending decisions.")
                        } else {
                            ForEach(pendingDecisionTasks) { task in
                                taskButton(task, statusOverride: task.status == .inbox ? .needsDecision : nil)
                            }
                        }
                    }
                }
            }
            .padding(DLSpacing.lg)
        }
        .background(DLColor.background)
        .navigationTitle("Today")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DLSpacing.xs) {
                Text(Date.now, style: .date)
                    .font(.callout)
                    .foregroundStyle(DLColor.textSecondary)
                Text("Today")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DLColor.textPrimary)
            }
            Spacer()
            Button(action: showCapture) {
                Image(systemName: "mic.fill")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(DLColor.primary, in: Circle())
            }
            .accessibilityLabel("Quick capture")
        }
    }

    private func section<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            VStack(alignment: .leading, spacing: DLSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DLColor.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DLColor.textSecondary)
            }
            content()
        }
    }

    private func taskButton(_ task: DLTask, statusOverride: DLStatus? = nil) -> some View {
        Button(action: { showTaskDetail(task.id) }) {
            DLTaskRow(
                task: TaskPreview(
                    id: task.id,
                    title: task.title,
                    nextAction: task.nextAction?.nonEmpty ?? task.summary?.nonEmpty ?? "Choose the next action.",
                    status: statusOverride ?? task.displayStatus
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func calendarBlockRow(_ task: DLTask) -> some View {
        Button(action: { showTaskDetail(task.id) }) {
            HStack(alignment: .top, spacing: DLSpacing.md) {
                VStack(alignment: .leading, spacing: DLSpacing.xs) {
                    Text(timeRange(for: task))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DLColor.primary)
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(DLColor.textPrimary)
                    Text(task.nextAction?.nonEmpty ?? task.summary?.nonEmpty ?? "Show up for this block.")
                        .font(.callout)
                        .foregroundStyle(DLColor.textSecondary)
                }
                Spacer()
                DLStatusBadge(status: task.displayStatus)
            }
            .padding(DLSpacing.md)
            .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DLRadius.md)
                    .stroke(DLColor.divider, lineWidth: 0.5)
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

    private func timeRange(for task: DLTask) -> String {
        guard let start = task.scheduledStart else { return "Unscheduled" }
        if let end = task.scheduledEnd {
            return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        }
        return start.formatted(date: .omitted, time: .shortened)
    }

    private func deterministicTopTaskSort(_ lhs: DLTask, _ rhs: DLTask) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority.sortRank > rhs.priority.sortRank
        }
        if lhs.sortDate != rhs.sortDate {
            return lhs.sortDate < rhs.sortDate
        }
        return lhs.createdAt < rhs.createdAt
    }
}

private extension DLTask {
    var isActive: Bool {
        status != .deleted && status != .done
    }

    var isCalendarBlock: Bool {
        scheduledStart != nil && scheduledEnd != nil && calendarEventID == nil
    }

    var belongsOnToday: Bool {
        if let scheduledStart {
            return Calendar.current.isDateInToday(scheduledStart)
        }

        if let dueDate {
            return Calendar.current.isDateInToday(dueDate)
        }

        return status == .snoozed || status == .blocked
    }

    var sortDate: Date {
        scheduledStart ?? dueDate ?? updatedAt
    }

    var displayStatus: DLStatus {
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
                return .calendarPending
            }
            return .notScheduled
        case .deleted:
            return .notScheduled
        }
    }

    func isOverdue(referenceDate: Date) -> Bool {
        if let scheduledStart {
            return scheduledStart < referenceDate && !Calendar.current.isDateInToday(scheduledStart)
        }

        if let dueDate {
            return dueDate < Calendar.current.startOfDay(for: referenceDate)
        }

        return false
    }
}

private extension DLTaskPriority {
    var sortRank: Int {
        switch self {
        case .high: 3
        case .normal: 2
        case .low: 1
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
