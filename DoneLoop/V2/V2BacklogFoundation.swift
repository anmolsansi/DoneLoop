import Foundation

struct DLWeeklyReviewSummary: Equatable {
    var startDate: Date
    var endDate: Date
    var completedCount: Int
    var snoozedCount: Int
    var blockedCount: Int
    var missedCount: Int
    var deletedCount: Int
    var stuckTasks: [DLStuckTask]
    var procrastinationPatterns: [DLProcrastinationPattern]
    var suggestedFocus: String
}

struct DLProcrastinationPattern: Identifiable, Equatable {
    var id: UUID
    var taskID: UUID
    var title: String
    var reason: String
    var suggestedDecision: String
}

struct DLProjectGroup: Identifiable, Equatable {
    var id: String
    var title: String
    var taskIDs: [UUID]
    var noteIDs: [UUID]
    var ideaIDs: [UUID]
    var summary: String
}

struct DLLocalSearchResult: Identifiable, Equatable {
    enum ItemType: String, Equatable {
        case task
        case capture
        case note
        case idea
    }

    var id: UUID
    var itemType: ItemType
    var title: String
    var detail: String
    var matchedText: String
}

struct DLRoutineDraft: Identifiable, Equatable {
    enum Frequency: String, Equatable {
        case daily
        case weekly
        case weekdays
    }

    var id: UUID
    var title: String
    var nextAction: String
    var frequency: Frequency
    var preferredHour: Int
    var defaultDurationMinutes: Int
}

struct DLTaskShrinkSuggestion: Equatable {
    var title: String
    var summary: String
    var nextAction: String
    var confidence: Double
}

struct DLStuckTask: Identifiable, Equatable {
    var id: UUID
    var title: String
    var reason: String
    var suggestedDecision: String
}

struct DLNoteCluster: Identifiable, Equatable {
    var id: String
    var title: String
    var noteIDs: [UUID]
    var ideaIDs: [UUID]
    var suggestedNextAction: String
}

enum DLV2WeeklyReviewEngine {
    static func summarize(tasks: [DLTask], now: Date = Date(), calendar: Calendar = .current) -> DLWeeklyReviewSummary {
        let endDate = now
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate.addingTimeInterval(-7 * 24 * 60 * 60)
        let recentTasks = tasks.filter { $0.updatedAt >= startDate && $0.updatedAt <= endDate }
        let stuckTasks = DLV2StuckTaskDetector.detect(in: tasks, now: now)
        let patterns = DLV2ProcrastinationPatternDetector.detect(in: tasks)

        return DLWeeklyReviewSummary(
            startDate: startDate,
            endDate: endDate,
            completedCount: recentTasks.filter { $0.status == .done }.count,
            snoozedCount: recentTasks.filter { $0.snoozeCount > 0 }.count,
            blockedCount: recentTasks.filter { $0.status == .blocked }.count,
            missedCount: recentTasks.reduce(0) { $0 + $1.missedCount },
            deletedCount: recentTasks.filter { $0.status == .deleted }.count,
            stuckTasks: Array(stuckTasks.prefix(5)),
            procrastinationPatterns: Array(patterns.prefix(5)),
            suggestedFocus: suggestedFocus(from: recentTasks, stuckTasks: stuckTasks)
        )
    }

    private static func suggestedFocus(from tasks: [DLTask], stuckTasks: [DLStuckTask]) -> String {
        if !stuckTasks.isEmpty {
            return "Shrink or block the stuck tasks before adding more work."
        }
        if tasks.contains(where: { $0.status == .done }) {
            return "Review what worked and repeat the smallest useful routines."
        }
        return "Pick one task for Today and make the next action concrete."
    }
}

enum DLV2ProcrastinationPatternDetector {
    static func detect(in tasks: [DLTask]) -> [DLProcrastinationPattern] {
        tasks
            .filter { $0.status != .done && $0.status != .deleted }
            .compactMap { task in
                if task.snoozeCount >= 2 {
                    return DLProcrastinationPattern(
                        id: task.id,
                        taskID: task.id,
                        title: task.title,
                        reason: "Snoozed \(task.snoozeCount) times.",
                        suggestedDecision: "Shrink this task or mark it blocked."
                    )
                }

                if task.missedCount > 0 {
                    return DLProcrastinationPattern(
                        id: task.id,
                        taskID: task.id,
                        title: task.title,
                        reason: "Missed \(task.missedCount) reminders.",
                        suggestedDecision: "Reschedule it to a real time or delete it."
                    )
                }

                if task.status == .blocked {
                    return DLProcrastinationPattern(
                        id: task.id,
                        taskID: task.id,
                        title: task.title,
                        reason: "Marked blocked.",
                        suggestedDecision: "Name the blocker or delete the task."
                    )
                }

                return nil
            }
            .sorted { lhs, rhs in lhs.reason < rhs.reason }
    }
}

enum DLV2ProjectGroupingEngine {
    static func group(tasks: [DLTask], notes: [DLNote], ideas: [DLIdea]) -> [DLProjectGroup] {
        let keys = Set(
            tasks.compactMap(\.projectKey)
                + notes.compactMap(\.projectKey)
                + ideas.compactMap(\.projectKey)
        )

        return keys.sorted().map { key in
            let groupedTasks = tasks.filter { $0.projectKey == key }
            let groupedNotes = notes.filter { $0.projectKey == key }
            let groupedIdeas = ideas.filter { $0.projectKey == key }
            return DLProjectGroup(
                id: key,
                title: key.displayTitle,
                taskIDs: groupedTasks.map(\.id),
                noteIDs: groupedNotes.map(\.id),
                ideaIDs: groupedIdeas.map(\.id),
                summary: "\(groupedTasks.count) tasks, \(groupedNotes.count) notes, \(groupedIdeas.count) ideas"
            )
        }
    }
}

enum DLV2NotionArchiveExporter {
    static func weeklyMarkdown(summary: DLWeeklyReviewSummary) -> String {
        var lines = [
            "# DoneLoop Weekly Review",
            "",
            "Period: \(summary.startDate.formatted(date: .abbreviated, time: .omitted)) - \(summary.endDate.formatted(date: .abbreviated, time: .omitted))",
            "",
            "## Counts",
            "",
            "- Completed: \(summary.completedCount)",
            "- Snoozed: \(summary.snoozedCount)",
            "- Blocked: \(summary.blockedCount)",
            "- Missed reminders: \(summary.missedCount)",
            "- Deleted: \(summary.deletedCount)",
            "",
            "## Suggested focus",
            "",
            summary.suggestedFocus
        ]

        if !summary.stuckTasks.isEmpty {
            lines.append(contentsOf: ["", "## Stuck tasks", ""])
            lines.append(contentsOf: summary.stuckTasks.map { "- \($0.title): \($0.suggestedDecision)" })
        }

        return lines.joined(separator: "\n")
    }
}

enum DLV2LocalSearchEngine {
    static func search(query: String, tasks: [DLTask], captures: [DLCapture], notes: [DLNote], ideas: [DLIdea]) -> [DLLocalSearchResult] {
        let terms = query.searchTerms
        guard !terms.isEmpty else { return [] }

        let taskResults = tasks.compactMap { task -> DLLocalSearchResult? in
            let text = [task.title, task.summary, task.nextAction, task.category].compactMap { $0 }.joined(separator: " ")
            guard text.matchesAll(terms) else { return nil }
            return DLLocalSearchResult(id: task.id, itemType: .task, title: task.title, detail: task.nextAction ?? task.summary ?? "", matchedText: text)
        }

        let captureResults = captures.compactMap { capture -> DLLocalSearchResult? in
            let text = [capture.rawText, capture.transcript, capture.aiOutputJSON].compactMap { $0 }.joined(separator: " ")
            guard text.matchesAll(terms) else { return nil }
            return DLLocalSearchResult(id: capture.id, itemType: .capture, title: capture.transcript ?? capture.rawText, detail: capture.processingStatus.displayName, matchedText: text)
        }

        let noteResults = notes.compactMap { note -> DLLocalSearchResult? in
            let text = [note.title, note.content, note.summary, note.category].compactMap { $0 }.joined(separator: " ")
            guard text.matchesAll(terms) else { return nil }
            return DLLocalSearchResult(id: note.id, itemType: .note, title: note.title, detail: note.summary ?? note.content, matchedText: text)
        }

        let ideaResults = ideas.compactMap { idea -> DLLocalSearchResult? in
            let text = [idea.title, idea.summary, idea.suggestedNextAction].compactMap { $0 }.joined(separator: " ")
            guard text.matchesAll(terms) else { return nil }
            return DLLocalSearchResult(id: idea.id, itemType: .idea, title: idea.title, detail: idea.suggestedNextAction ?? idea.summary ?? "", matchedText: text)
        }

        return (taskResults + captureResults + noteResults + ideaResults)
            .sorted { lhs, rhs in lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
    }
}

enum DLV2RoutineEngine {
    static func makeRoutineDraft(from task: DLTask, frequency: DLRoutineDraft.Frequency, settings: DLUserSettings) -> DLRoutineDraft {
        DLRoutineDraft(
            id: UUID(),
            title: task.title,
            nextAction: task.nextAction ?? "Start the routine.",
            frequency: frequency,
            preferredHour: settings.preferredWorkStartHour,
            defaultDurationMinutes: settings.defaultTaskDurationMinutes
        )
    }
}

enum DLV2TaskShrinkEngine {
    static func suggest(for task: DLTask) -> DLTaskShrinkSuggestion {
        let lowercased = task.title.lowercased()
        if lowercased.contains("5 jobs") || lowercased.contains("five jobs") || lowercased.contains("jobs") {
            return DLTaskShrinkSuggestion(
                title: "Apply to 1 job",
                summary: "Smaller version of: \(task.title)",
                nextAction: "Open one saved job link.",
                confidence: 0.9
            )
        }

        if lowercased.contains("resume") {
            return DLTaskShrinkSuggestion(
                title: "Improve one resume section",
                summary: "Smaller version of: \(task.title)",
                nextAction: "Open the resume and edit one bullet.",
                confidence: 0.86
            )
        }

        if let nextAction = task.nextAction?.nonEmpty {
            return DLTaskShrinkSuggestion(
                title: "Start: \(task.title)",
                summary: "Smaller version of: \(task.title)",
                nextAction: nextAction,
                confidence: 0.72
            )
        }

        return DLTaskShrinkSuggestion(
            title: "Start: \(task.title)",
            summary: "Smaller version of: \(task.title)",
            nextAction: "Do the first visible two-minute step.",
            confidence: 0.62
        )
    }
}

enum DLV2StuckTaskDetector {
    static func detect(in tasks: [DLTask], now: Date = Date()) -> [DLStuckTask] {
        tasks.compactMap { task in
            guard task.status != .done && task.status != .deleted else { return nil }

            if task.snoozeCount >= 2 {
                return DLStuckTask(id: task.id, title: task.title, reason: "Snoozed \(task.snoozeCount) times.", suggestedDecision: "Shrink it.")
            }

            if task.status == .blocked {
                return DLStuckTask(id: task.id, title: task.title, reason: "Blocked.", suggestedDecision: "Name the blocker.")
            }

            if let dueDate = task.dueDate, dueDate < now, task.missedCount > 0 {
                return DLStuckTask(id: task.id, title: task.title, reason: "Overdue with missed reminders.", suggestedDecision: "Reschedule or delete it.")
            }

            return nil
        }
    }
}

enum DLV2SemanticNoteOrganizer {
    static func cluster(notes: [DLNote], ideas: [DLIdea]) -> [DLNoteCluster] {
        let keys = Set(notes.compactMap(\.clusterKey) + ideas.compactMap(\.clusterKey))

        return keys.sorted().map { key in
            let groupedNotes = notes.filter { $0.clusterKey == key }
            let groupedIdeas = ideas.filter { $0.clusterKey == key }
            return DLNoteCluster(
                id: key,
                title: key.displayTitle,
                noteIDs: groupedNotes.map(\.id),
                ideaIDs: groupedIdeas.map(\.id),
                suggestedNextAction: groupedIdeas.isEmpty ? "Review these notes later." : "Decide if one idea should become a task."
            )
        }
    }
}

private extension DLTask {
    var projectKey: String? {
        category?.normalizedKey ?? title.firstMeaningfulWord
    }
}

private extension DLNote {
    var projectKey: String? {
        category?.normalizedKey ?? title.firstMeaningfulWord
    }

    var clusterKey: String? {
        category?.normalizedKey ?? summary?.firstMeaningfulWord ?? title.firstMeaningfulWord
    }
}

private extension DLIdea {
    var projectKey: String? {
        summary?.firstMeaningfulWord ?? title.firstMeaningfulWord
    }

    var clusterKey: String? {
        summary?.firstMeaningfulWord ?? suggestedNextAction?.firstMeaningfulWord ?? title.firstMeaningfulWord
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedKey: String? {
        let normalized = lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return normalized.isEmpty ? nil : normalized
    }

    var displayTitle: String {
        split(separator: "-")
            .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            .joined(separator: " ")
    }

    var firstMeaningfulWord: String? {
        let stopWords: Set<String> = ["the", "this", "that", "and", "for", "with", "work", "task", "note", "idea", "should"]
        return lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .first { word in word.count > 2 && !stopWords.contains(word) }
    }

    var searchTerms: [String] {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    func matchesAll(_ terms: [String]) -> Bool {
        let lowercasedText = lowercased()
        return terms.allSatisfy { lowercasedText.contains($0) }
    }
}
