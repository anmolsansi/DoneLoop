import Foundation

@MainActor
final class LocalStore: ObservableObject {
    @Published private(set) var tasks: [DLTask]
    @Published private(set) var captures: [DLCapture]
    @Published private(set) var notes: [DLNote]
    @Published private(set) var ideas: [DLIdea]
    @Published private(set) var settings: DLUserSettings
    @Published private(set) var lastErrorMessage: String?

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var storePath: String {
        fileURL.path
    }

    var latestParserOutputPreview: String {
        captures
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap(\.aiOutputJSON)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? "No parser output saved yet."
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? LocalStore.defaultStoreURL()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        let storeFileExists = FileManager.default.fileExists(atPath: self.fileURL.path)

        if let snapshot = Self.loadSnapshot(from: self.fileURL, decoder: self.decoder) {
            self.tasks = snapshot.tasks
            self.captures = snapshot.captures
            self.notes = snapshot.notes
            self.ideas = snapshot.ideas
            self.settings = snapshot.settings
            self.lastErrorMessage = nil
        } else {
            self.tasks = []
            self.captures = []
            self.notes = []
            self.ideas = []
            self.settings = .defaults()
            self.lastErrorMessage = storeFileExists ? "Local data could not be loaded." : nil

            if !storeFileExists {
                persist()
            }
        }
    }

    var recentCaptures: [CapturePreview] {
        captures
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(10)
            .map { capture in
                CapturePreview(
                    id: capture.id,
                    title: capture.transcript?.nonEmpty ?? capture.rawText.nonEmpty ?? "Untitled capture",
                    detail: capture.aiOutputJSON == nil ? "No interpretation saved yet" : "Structured output saved",
                    source: capture.source.displayName,
                    status: capture.processingStatus.displayName,
                    timestamp: capture.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
    }

    func capture(id: UUID) -> DLCapture? {
        captures.first { $0.id == id }
    }

    func task(id: UUID) -> DLTask? {
        tasks.first { $0.id == id }
    }

    var todayTasks: [TaskPreview] {
        let today = Calendar.current.startOfDay(for: Date())
        return tasks
            .filter { task in
                task.status != .deleted && task.status != .done && task.belongsToDay(today)
            }
            .sorted(by: taskSort)
            .prefix(3)
            .map(TaskPreview.init(task:))
    }

    var inboxItems: [TaskPreview] {
        tasks
            .filter { task in
                task.status == .inbox && task.scheduledStart == nil && task.status != .deleted
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map(TaskPreview.init(task:))
    }

    @discardableResult
    func createCapture(
        rawText: String,
        source: DLCaptureSource,
        transcript: String? = nil,
        audioFilePath: String? = nil,
        processingStatus: DLCaptureProcessingStatus = .readyToInterpret
    ) -> DLCapture {
        let capture = DLCapture(
            rawText: rawText,
            audioFilePath: audioFilePath,
            transcript: transcript,
            source: source,
            processingStatus: processingStatus
        )
        captures.insert(capture, at: 0)
        persist()
        return capture
    }

    @discardableResult
    func upsertCapture(_ capture: DLCapture) -> DLCapture {
        if let index = captures.firstIndex(where: { $0.id == capture.id }) {
            captures[index] = capture
        } else {
            captures.insert(capture, at: 0)
        }

        persist()
        return capture
    }

    @discardableResult
    func upsertTask(_ task: DLTask) -> DLTask {
        var updatedTask = task
        updatedTask.updatedAt = Date()

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = updatedTask
        } else {
            tasks.insert(updatedTask, at: 0)
        }

        persist()
        return updatedTask
    }

    func updateTask(_ id: UUID, transform: (inout DLTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        transform(&tasks[index])
        tasks[index].updatedAt = Date()
        persist()
    }

    func deleteTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = .deleted
        tasks[index].calendarSyncStatus = tasks[index].calendarEventID == nil ? .notScheduled : .pending
        tasks[index].notificationStatus = .notScheduled
        tasks[index].notificationID = nil
        tasks[index].notificationError = nil
        tasks[index].updatedAt = Date()
        persist()
    }

    func updateTaskStatus(id: UUID, status: DLTaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = status
        if status == .deleted {
            tasks[index].calendarSyncStatus = tasks[index].calendarEventID == nil ? .notScheduled : .pending
        }
        if status == .done || status == .deleted {
            tasks[index].notificationStatus = .notScheduled
            tasks[index].notificationID = nil
            tasks[index].notificationError = nil
        }
        tasks[index].updatedAt = Date()
        persist()
    }

    func snoozeTask(id: UUID, minutes: Int? = nil) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let snoozeMinutes = minutes ?? settings.defaultSnoozeMinutes
        tasks[index].status = .snoozed
        tasks[index].snoozeCount += 1
        tasks[index].dueDate = Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60))
        tasks[index].dueTime = tasks[index].dueDate
        tasks[index].notificationStatus = .pendingPermission
        tasks[index].notificationID = nil
        tasks[index].notificationError = nil
        tasks[index].updatedAt = Date()
        persist()
    }

    func rescheduleTask(id: UUID, start: Date, durationMinutes: Int) {
        updateTask(id) { task in
            task.status = .scheduled
            task.scheduledStart = start
            task.scheduledEnd = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            task.dueDate = start
            task.dueTime = start
            task.calendarSyncStatus = task.calendarEventID == nil ? .pending : task.calendarSyncStatus
            task.calendarSyncError = nil
            task.notificationStatus = .pendingPermission
            task.notificationID = nil
            task.notificationError = nil
        }
    }

    func markTaskNotificationScheduled(id: UUID, notificationID: String) {
        updateTask(id) { task in
            task.notificationID = notificationID
            task.notificationStatus = .scheduled
            task.notificationError = nil
        }
    }

    func markTaskNotificationNotScheduled(id: UUID) {
        updateTask(id) { task in
            task.notificationID = nil
            task.notificationStatus = .notScheduled
            task.notificationError = nil
        }
    }

    func markTaskNotificationPermissionDenied(id: UUID) {
        updateTask(id) { task in
            task.notificationID = nil
            task.notificationStatus = .permissionDenied
            task.notificationError = "Notification permission is denied."
        }
    }

    func markTaskNotificationFailed(id: UUID, message: String) {
        updateTask(id) { task in
            task.notificationID = nil
            task.notificationStatus = .failed
            task.notificationError = message
        }
    }

    @discardableResult
    func shrinkTask(id: UUID) -> DLTask? {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return nil }
        let current = tasks[index]
        let suggestion = Self.breakdownSuggestions(for: current).first ?? DLBreakdownSuggestion.fallback(for: current)
        tasks[index].title = suggestion.title
        tasks[index].nextAction = suggestion.nextAction
        tasks[index].summary = suggestion.summary
        tasks[index].status = .inProgress
        tasks[index].updatedAt = Date()
        persist()
        return tasks[index]
    }

    func breakdownSuggestions(for taskID: UUID) -> [DLBreakdownSuggestion] {
        guard let task = task(id: taskID) else { return [] }
        return Self.breakdownSuggestions(for: task)
    }

    @discardableResult
    func applyBreakdownSuggestion(id: UUID, suggestion: DLBreakdownSuggestion) -> DLTask? {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return nil }
        tasks[index].title = suggestion.title
        tasks[index].summary = suggestion.summary
        tasks[index].nextAction = suggestion.nextAction
        tasks[index].status = .inProgress
        tasks[index].updatedAt = Date()
        persist()
        return tasks[index]
    }

    func markTaskCalendarSynced(id: UUID, eventID: String) {
        updateTask(id) { task in
            task.calendarEventID = eventID
            task.calendarSyncStatus = .synced
            task.calendarSyncError = nil
        }
    }

    func markTaskCalendarSyncFailed(id: UUID, message: String) {
        updateTask(id) { task in
            task.calendarSyncStatus = .failed
            task.calendarSyncError = message
        }
    }

    func markTaskCalendarDisconnected(id: UUID, message: String? = nil) {
        updateTask(id) { task in
            task.calendarSyncStatus = .disconnected
            task.calendarSyncError = message
        }
    }

    func markTaskCalendarSyncNotScheduled(id: UUID) {
        updateTask(id) { task in
            task.calendarSyncStatus = .notScheduled
            task.calendarSyncError = nil
        }
    }

    func disconnectTaskCalendarEvent(id: UUID) {
        updateTask(id) { task in
            task.calendarEventID = nil
            task.calendarSyncStatus = task.scheduledStart == nil ? .notScheduled : .pending
            task.calendarSyncError = nil
        }
    }

    func markSyncedCalendarTasksDisconnected() {
        for task in tasks where task.calendarEventID != nil || task.calendarSyncStatus == .synced {
            updateTask(task.id) { updatedTask in
                updatedTask.calendarSyncStatus = .disconnected
                updatedTask.calendarSyncError = nil
            }
        }
    }

    func deleteCapture(id: UUID) {
        captures.removeAll { $0.id == id }
        persist()
    }

    @discardableResult
    func upsertNote(_ note: DLNote) -> DLNote {
        var updatedNote = note
        updatedNote.updatedAt = Date()
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = updatedNote
        } else {
            notes.insert(updatedNote, at: 0)
        }
        persist()
        return updatedNote
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        persist()
    }

    @discardableResult
    func upsertIdea(_ idea: DLIdea) -> DLIdea {
        var updatedIdea = idea
        updatedIdea.updatedAt = Date()
        if let index = ideas.firstIndex(where: { $0.id == idea.id }) {
            ideas[index] = updatedIdea
        } else {
            ideas.insert(updatedIdea, at: 0)
        }
        persist()
        return updatedIdea
    }

    func deleteIdea(id: UUID) {
        ideas.removeAll { $0.id == id }
        persist()
    }

    func updateSettings(_ transform: (inout DLUserSettings) -> Void) {
        var updatedSettings = settings
        transform(&updatedSettings)
        updatedSettings.updatedAt = Date()
        settings = updatedSettings
        persist()
    }

    func completeOnboarding() {
        updateSettings { settings in
            settings.hasCompletedOnboarding = true
        }
    }

    func resetOnboarding() {
        updateSettings { settings in
            settings.hasCompletedOnboarding = false
        }
    }

    func resetLocalData(keepOnboardingCompleted: Bool = true) {
        tasks = []
        captures = []
        notes = []
        ideas = []
        settings = .defaults()
        settings.hasCompletedOnboarding = keepOnboardingCompleted
        settings.updatedAt = Date()
        persist()
    }

    func searchLocalContent(_ query: String) -> [DLV1LocalSearchResult] {
        let normalizedQuery = query.normalizedSearchText
        guard !normalizedQuery.isEmpty else { return [] }

        var results: [DLV1LocalSearchResult] = []

        results += tasks
            .filter { $0.status != .deleted }
            .compactMap { task in
                match(
                    query: normalizedQuery,
                    type: .task,
                    id: task.id,
                    title: task.title,
                    searchableParts: [task.title, task.summary, task.nextAction, task.category],
                    detailFallback: task.nextAction ?? task.summary ?? task.status.rawValue
                )
            }

        results += notes.compactMap { note in
            match(
                query: normalizedQuery,
                type: note.category == "brain_dump" ? .brainDump : .note,
                id: note.id,
                title: note.title,
                searchableParts: [note.title, note.content, note.summary, note.category],
                detailFallback: note.summary ?? note.content
            )
        }

        results += ideas
            .filter { $0.convertedToTaskID == nil }
            .compactMap { idea in
                match(
                    query: normalizedQuery,
                    type: .idea,
                    id: idea.id,
                    title: idea.title,
                    searchableParts: [idea.title, idea.summary, idea.suggestedNextAction],
                    detailFallback: idea.suggestedNextAction ?? idea.summary ?? "Idea"
                )
            }

        results += captures.compactMap { capture in
            match(
                query: normalizedQuery,
                type: .capture,
                id: capture.id,
                title: capture.transcript ?? capture.rawText,
                searchableParts: [capture.rawText, capture.transcript, capture.aiOutputJSON],
                detailFallback: capture.source.displayName
            )
        }

        return results
            .sorted { lhs, rhs in
                if lhs.type.sortRank != rhs.type.sortRank {
                    return lhs.type.sortRank < rhs.type.sortRank
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func reload() {
        guard let snapshot = Self.loadSnapshot(from: fileURL, decoder: decoder) else { return }
        tasks = snapshot.tasks
        captures = snapshot.captures
        notes = snapshot.notes
        ideas = snapshot.ideas
        settings = snapshot.settings
        lastErrorMessage = nil
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let snapshot = LocalStoreSnapshot(
                schemaVersion: LocalStoreSnapshot.currentSchemaVersion,
                tasks: tasks,
                captures: captures,
                notes: notes,
                ideas: ideas,
                settings: settings
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Local data could not be saved."
        }
    }

    private static func loadSnapshot(from fileURL: URL, decoder: JSONDecoder) -> LocalStoreSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(LocalStoreSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    private static func defaultStoreURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("DoneLoop", isDirectory: true)
            .appendingPathComponent("local-store.json")
    }

    private func taskSort(_ lhs: DLTask, _ rhs: DLTask) -> Bool {
        let lhsDate = lhs.scheduledStart ?? lhs.dueDate ?? lhs.updatedAt
        let rhsDate = rhs.scheduledStart ?? rhs.dueDate ?? rhs.updatedAt
        return lhsDate < rhsDate
    }

    private func match(
        query: String,
        type: DLV1LocalSearchResult.ResultType,
        id: UUID,
        title: String,
        searchableParts: [String?],
        detailFallback: String
    ) -> DLV1LocalSearchResult? {
        let searchableText = searchableParts
            .compactMap { $0?.normalizedSearchText }
            .joined(separator: " ")
        guard searchableText.contains(query) else { return nil }

        return DLV1LocalSearchResult(
            type: type,
            itemID: id,
            title: title.nonEmpty ?? "Untitled \(type.displayName.lowercased())",
            detail: detailFallback.nonEmpty ?? type.displayName
        )
    }
}

struct DLV1LocalSearchResult: Identifiable, Equatable {
    enum ResultType: String, Equatable {
        case task
        case note
        case idea
        case brainDump
        case capture

        var displayName: String {
            switch self {
            case .task: "Task"
            case .note: "Note"
            case .idea: "Idea"
            case .brainDump: "Brain dump"
            case .capture: "Capture"
            }
        }

        var systemImage: String {
            switch self {
            case .task: "checklist"
            case .note: "note.text"
            case .idea: "lightbulb"
            case .brainDump: "tray.full"
            case .capture: "quote.bubble"
            }
        }

        var sortRank: Int {
            switch self {
            case .task: 0
            case .note: 1
            case .idea: 2
            case .brainDump: 3
            case .capture: 4
            }
        }
    }

    var id: String { "\(type.rawValue)-\(itemID.uuidString)" }
    var type: ResultType
    var itemID: UUID
    var title: String
    var detail: String
}

private extension LocalStore {
    static func breakdownSuggestions(for task: DLTask) -> [DLBreakdownSuggestion] {
        let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = title.lowercased()

        if lowercased.contains("5 jobs") || lowercased.contains("five jobs") {
            return [
                DLBreakdownSuggestion(
                    title: "Apply to 1 job",
                    summary: "Smaller version of: \(title)",
                    nextAction: "Open one saved job link."
                ),
                DLBreakdownSuggestion(
                    title: "Pick 1 job to apply for",
                    summary: "Decision-only version of: \(title)",
                    nextAction: "Open saved roles and choose one listing."
                )
            ]
        }

        if lowercased.contains("jobs") {
            return [
                DLBreakdownSuggestion(
                    title: "Apply to 1 job",
                    summary: "Smaller version of: \(title)",
                    nextAction: "Open one job link and start the application."
                ),
                DLBreakdownSuggestion(
                    title: "Find one job link",
                    summary: "Starter version of: \(title)",
                    nextAction: "Open the job board and save one role."
                )
            ]
        }

        if lowercased.contains("resume") {
            return [
                DLBreakdownSuggestion(
                    title: "Improve one resume section",
                    summary: "Smaller version of: \(title)",
                    nextAction: "Open the resume and edit one bullet."
                ),
                DLBreakdownSuggestion(
                    title: "Choose one resume bullet",
                    summary: "Decision-only version of: \(title)",
                    nextAction: "Open the resume and highlight one bullet to improve."
                )
            ]
        }

        if lowercased.contains("email") {
            return [
                DLBreakdownSuggestion(
                    title: "Draft the first email line",
                    summary: "Smaller version of: \(title)",
                    nextAction: "Open the email draft and write the first sentence."
                )
            ]
        }

        return [DLBreakdownSuggestion.fallback(for: task)]
    }
}

struct DLBreakdownSuggestion: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var summary: String
    var nextAction: String

    static func fallback(for task: DLTask) -> DLBreakdownSuggestion {
        let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return DLBreakdownSuggestion(
            title: "Start: \(title.isEmpty ? "this task" : title)",
            summary: "Smaller version of: \(title.isEmpty ? "Untitled task" : title)",
            nextAction: task.nextAction?.nonEmpty ?? "Do the first visible two-minute step."
        )
    }
}

private struct LocalStoreSnapshot: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var tasks: [DLTask]
    var captures: [DLCapture]
    var notes: [DLNote]
    var ideas: [DLIdea]
    var settings: DLUserSettings
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedSearchText: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
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

private extension DLTask {
    func belongsToDay(_ day: Date) -> Bool {
        let calendar = Calendar.current

        if let scheduledStart {
            return calendar.isDate(scheduledStart, inSameDayAs: day)
        }

        if let dueDate {
            return calendar.isDate(dueDate, inSameDayAs: day)
        }

        return status == .blocked || status == .snoozed
    }
}

private extension TaskPreview {
    init(task: DLTask) {
        self.init(
            id: task.id,
            title: task.title,
            nextAction: task.nextAction?.nonEmpty ?? task.summary?.nonEmpty ?? "No next action yet",
            status: DLStatus(task: task)
        )
    }
}

private extension DLStatus {
    init(task: DLTask) {
        switch task.status {
        case .done:
            self = .done
        case .blocked:
            self = .blocked
        case .inbox:
            self = .notScheduled
        case .scheduled, .inProgress, .snoozed:
            if task.calendarSyncStatus == .failed {
                self = .calendarFailed
            } else if task.calendarSyncStatus == .disconnected {
                self = .calendarDisconnected
            } else if task.calendarEventID != nil || task.calendarSyncStatus == .synced {
                self = .calendarSynced
            } else if task.scheduledStart != nil {
                self = .calendarPending
            } else {
                self = .notScheduled
            }
        case .deleted:
            self = .notScheduled
        }
    }
}
