import Foundation
import UserNotifications

enum DLNotificationServiceError: Error, Equatable {
    case permissionDenied
    case missingTask
    case missingReminderDate
    case pastReminderDate
}

@MainActor
final class NotificationService: NSObject, ObservableObject {
    @Published private(set) var openedTaskID: UUID?
    @Published private(set) var fallbackMessage: String?

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        self.center.delegate = self
    }

    var permissionLabel: String {
        "Stored in Settings"
    }

    func refreshAuthorizationStatus(store: LocalStore) {
        center.getNotificationSettings { settings in
            Task { @MainActor in
                store.updateSettings { localSettings in
                    localSettings.notificationPermissionStatus = Self.permissionStatus(from: settings.authorizationStatus)
                    localSettings.remindersEnabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                }
            }
        }
    }

    func requestPermission(store: LocalStore) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                store.updateSettings { settings in
                    settings.notificationPermissionStatus = granted ? .granted : .denied
                    settings.remindersEnabled = granted
                }

                if granted {
                    self.scheduleAllEligibleTasks(in: store)
                } else {
                    for task in store.tasks where task.reminderDate != nil && task.status != .done && task.status != .deleted {
                        store.markTaskNotificationPermissionDenied(id: task.id)
                    }
                }
            }
        }
    }

    func scheduleAllEligibleTasks(in store: LocalStore) {
        guard store.settings.remindersEnabled else { return }
        for task in store.tasks where task.reminderDate != nil && task.status != .done && task.status != .deleted {
            _ = scheduleReminder(for: task.id, in: store)
        }
    }

    @discardableResult
    func scheduleReminder(for taskID: UUID, in store: LocalStore) -> Result<String, DLNotificationServiceError> {
        guard store.settings.notificationPermissionStatus == .granted || store.settings.notificationPermissionStatus == .provisional else {
            store.markTaskNotificationPermissionDenied(id: taskID)
            return .failure(.permissionDenied)
        }

        guard let task = store.task(id: taskID), task.status != .done, task.status != .deleted else {
            store.markTaskNotificationNotScheduled(id: taskID)
            return .failure(.missingTask)
        }

        guard let reminderDate = task.reminderDate else {
            store.markTaskNotificationNotScheduled(id: taskID)
            return .failure(.missingReminderDate)
        }

        guard reminderDate > Date() else {
            store.markTaskNotificationFailed(id: taskID, message: "Reminder time is in the past.")
            return .failure(.pastReminderDate)
        }

        if let existingID = task.notificationID {
            center.removePendingNotificationRequests(withIdentifiers: [existingID])
        }

        let notificationID = "doneloop-task-\(task.id.uuidString.lowercased())"
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = task.nextAction ?? task.summary ?? "Choose Done, Snooze, Reschedule, Break down, Blocked, or Delete."
        content.sound = .default
        content.userInfo = ["taskID": task.id.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)

        center.add(request) { error in
            Task { @MainActor in
                if let error {
                    store.markTaskNotificationFailed(id: taskID, message: error.localizedDescription)
                } else {
                    store.markTaskNotificationScheduled(id: taskID, notificationID: notificationID)
                }
            }
        }

        store.markTaskNotificationScheduled(id: taskID, notificationID: notificationID)
        return .success(notificationID)
    }

    func cancelReminder(for taskID: UUID, in store: LocalStore) {
        if let notificationID = store.task(id: taskID)?.notificationID {
            center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        }
        store.markTaskNotificationNotScheduled(id: taskID)
    }

    func consumeOpenedTaskID() {
        openedTaskID = nil
    }

    func consumeFallbackMessage() {
        fallbackMessage = nil
    }

    private static func permissionStatus(from status: UNAuthorizationStatus) -> DLNotificationPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .ephemeral:
            return .granted
        case .provisional:
            return .provisional
        @unknown default:
            return .notDetermined
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let taskID = response.notification.request.content.userInfo["taskID"] as? String
        Task { @MainActor in
            if let taskID, let uuid = UUID(uuidString: taskID) {
                self.openedTaskID = uuid
            } else {
                self.fallbackMessage = "This reminder did not include a task ID."
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let taskID = notification.request.content.userInfo["taskID"] as? String
        Task { @MainActor in
            if let taskID, let uuid = UUID(uuidString: taskID) {
                self.openedTaskID = uuid
            } else {
                self.fallbackMessage = "This reminder did not include a task ID."
            }
        }
        completionHandler([.banner, .sound])
    }
}

private extension DLTask {
    var reminderDate: Date? {
        scheduledStart ?? dueDate ?? dueTime
    }
}
