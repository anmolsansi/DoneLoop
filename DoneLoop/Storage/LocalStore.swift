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

    func deleteTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = .deleted
        tasks[index].calendarEventID = nil
        tasks[index].updatedAt = Date()
        persist()
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
            if task.calendarEventID != nil {
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
