import Foundation

enum DLCreatedItemDestination: String, Equatable {
    case today
    case inbox
    case notes
    case ideas
}

struct DLCreatedItemSummary: Identifiable, Equatable {
    var id: UUID
    var title: String
    var type: DLParsedItemType
    var destination: DLCreatedItemDestination
}

struct DLCreationResult: Equatable {
    var createdItems: [DLCreatedItemSummary]

    var taskCount: Int {
        createdItems.filter { [.task, .reminder, .calendarBlock].contains($0.type) }.count
    }

    var noteCount: Int {
        createdItems.filter { [.note, .brainDump].contains($0.type) }.count
    }

    var ideaCount: Int {
        createdItems.filter { $0.type == .idea }.count
    }

    var inboxCount: Int {
        createdItems.filter { $0.destination == .inbox }.count
    }

    var todayCount: Int {
        createdItems.filter { $0.destination == .today }.count
    }

    var confirmationMessage: String {
        let total = createdItems.count
        let itemWord = total == 1 ? "item" : "items"
        return "Saved \(total) \(itemWord). \(todayCount) for Today, \(inboxCount) in Inbox."
    }
}

enum DLCreationError: Error, Equatable {
    case validation([DLValidationIssue])
}

enum DLItemCreationEngine {
    @MainActor
    static func createItems(
        from output: DLParserOutput,
        validation: DLParserValidationResult,
        in store: LocalStore,
        provider: DLAIProvider = .ruleBased,
        now: Date = Date()
    ) -> Result<DLCreationResult, DLCreationError> {
        guard validation.canSave else {
            return .failure(.validation(validation.blockingIssues))
        }

        var createdItems: [DLCreatedItemSummary] = []

        for item in output.items {
            switch item.type {
            case .task, .reminder, .calendarBlock:
                let task = store.upsertTask(
                    DLTask(
                        id: item.id,
                        title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        summary: item.summary,
                        nextAction: item.nextAction,
                        status: taskStatus(for: item),
                        priority: item.priority,
                        category: item.category,
                        dueDate: item.dueDate,
                        dueTime: item.dueTime,
                        scheduledStart: item.scheduledStart,
                        scheduledEnd: item.scheduledEnd,
                        calendarEventID: nil,
                        sourceCaptureID: output.sourceCaptureID,
                        aiProviderUsed: provider,
                        createdAt: now,
                        updatedAt: now
                    )
                )

                createdItems.append(
                    DLCreatedItemSummary(
                        id: task.id,
                        title: task.title,
                        type: item.type,
                        destination: destination(for: task)
                    )
                )
            case .note, .brainDump:
                let note = store.upsertNote(
                    DLNote(
                        id: item.id,
                        title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        content: item.summary ?? item.title,
                        summary: item.summary,
                        category: item.category,
                        sourceCaptureID: output.sourceCaptureID,
                        createdAt: now,
                        updatedAt: now
                    )
                )

                createdItems.append(
                    DLCreatedItemSummary(
                        id: note.id,
                        title: note.title,
                        type: item.type,
                        destination: .notes
                    )
                )
            case .idea:
                let idea = store.upsertIdea(
                    DLIdea(
                        id: item.id,
                        title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        summary: item.summary,
                        suggestedNextAction: item.nextAction,
                        convertedToTaskID: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )

                createdItems.append(
                    DLCreatedItemSummary(
                        id: idea.id,
                        title: idea.title,
                        type: item.type,
                        destination: .ideas
                    )
                )
            }
        }

        if let sourceCaptureID = output.sourceCaptureID, var capture = store.capture(id: sourceCaptureID) {
            capture.processingStatus = .saved
            store.upsertCapture(capture)
        }

        return .success(DLCreationResult(createdItems: createdItems))
    }

    private static func taskStatus(for item: DLParsedItem) -> DLTaskStatus {
        if item.needsClarification {
            return .inbox
        }

        if item.scheduledStart != nil || item.dueDate != nil {
            return .scheduled
        }

        return .inbox
    }

    private static func destination(for task: DLTask) -> DLCreatedItemDestination {
        task.status == .inbox ? .inbox : .today
    }
}
