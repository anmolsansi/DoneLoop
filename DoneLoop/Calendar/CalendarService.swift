import Foundation

enum DLCalendarServiceError: Error, Equatable {
    case disconnected
    case missingSchedule
    case invalidSchedule
    case missingEvent
}

struct DLCalendarEventDraft: Equatable {
    var title: String
    var start: Date
    var end: Date
    var timeZoneIdentifier: String
    var notes: String
}

@MainActor
final class CalendarService: ObservableObject {
    var connectionLabel: String {
        "Google Calendar"
    }

    func connect(store: LocalStore) {
        store.updateSettings { settings in
            settings.googleCalendarConnectionStatus = .connected
            settings.googleCalendarID = "primary"
            settings.googleCalendarName = "Primary Calendar"
            settings.googleCalendarAccountEmail = "connected-google-account"
        }
        syncScheduledTasks(in: store)
    }

    func disconnect(store: LocalStore) {
        store.updateSettings { settings in
            settings.googleCalendarConnectionStatus = .disconnected
            settings.googleCalendarID = nil
            settings.googleCalendarName = nil
            settings.googleCalendarAccountEmail = nil
        }
        store.markSyncedCalendarTasksDisconnected()
    }

    func simulatePermissionDenied(store: LocalStore) {
        store.updateSettings { settings in
            settings.googleCalendarConnectionStatus = .permissionDenied
            settings.googleCalendarID = nil
            settings.googleCalendarName = nil
            settings.googleCalendarAccountEmail = nil
        }
    }

    func syncScheduledTasks(in store: LocalStore) {
        for task in store.tasks where shouldCreateCalendarEvent(for: task) {
            _ = createEvent(for: task.id, in: store)
        }
    }

    @discardableResult
    func createEvent(for taskID: UUID, in store: LocalStore) -> Result<String, DLCalendarServiceError> {
        guard isConnected(settings: store.settings) else {
            store.markTaskCalendarSyncFailed(id: taskID, message: "Google Calendar is disconnected.")
            return .failure(.disconnected)
        }

        guard let task = store.task(id: taskID), shouldCreateCalendarEvent(for: task) else {
            store.markTaskCalendarSyncNotScheduled(id: taskID)
            return .failure(.missingSchedule)
        }

        guard makeDraft(for: task, settings: store.settings) != nil else {
            store.markTaskCalendarSyncFailed(id: taskID, message: "Scheduled work needs a start and end time.")
            return .failure(.invalidSchedule)
        }

        let eventID = task.calendarEventID ?? "doneloop-\(task.id.uuidString.lowercased())"
        store.markTaskCalendarSynced(id: taskID, eventID: eventID)
        return .success(eventID)
    }

    @discardableResult
    func updateEvent(for taskID: UUID, in store: LocalStore) -> Result<String, DLCalendarServiceError> {
        guard let task = store.task(id: taskID), task.calendarEventID != nil else {
            return createEvent(for: taskID, in: store)
        }
        return createEvent(for: taskID, in: store)
    }

    @discardableResult
    func deleteEvent(for taskID: UUID, in store: LocalStore) -> Result<Void, DLCalendarServiceError> {
        guard isConnected(settings: store.settings) else {
            store.markTaskCalendarSyncFailed(id: taskID, message: "Google Calendar is disconnected.")
            return .failure(.disconnected)
        }
        guard let task = store.task(id: taskID), task.calendarEventID != nil else {
            return .failure(.missingEvent)
        }
        store.disconnectTaskCalendarEvent(id: taskID)
        return .success(())
    }

    func shouldCreateCalendarEvent(for task: DLTask) -> Bool {
        task.status != .deleted
            && task.status != .done
            && task.scheduledStart != nil
            && task.scheduledEnd != nil
    }

    func makeDraft(for task: DLTask, settings: DLUserSettings) -> DLCalendarEventDraft? {
        guard let start = task.scheduledStart, let end = task.scheduledEnd, end > start else { return nil }
        return DLCalendarEventDraft(
            title: task.title,
            start: start,
            end: end,
            timeZoneIdentifier: settings.timezoneIdentifier,
            notes: task.nextAction ?? task.summary ?? "Created by DoneLoop."
        )
    }

    func isConnected(settings: DLUserSettings) -> Bool {
        settings.googleCalendarConnectionStatus == .connected && settings.googleCalendarID != nil
    }
}
