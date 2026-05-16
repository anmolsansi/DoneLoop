import Foundation

final class AppServices: ObservableObject {
    let localStore = LocalStoreStub()
    let parser = ParserServiceStub()
    let calendar = CalendarServiceStub()
    let notifications = NotificationServiceStub()
}

struct LocalStoreStub {
    var recentCaptures: [CapturePreview] {
        [
            CapturePreview(title: "Tomorrow at 10, apply to Airbnb", detail: "Ready for interpretation", source: "Voice"),
            CapturePreview(title: "Work on resume", detail: "Needs clarification", source: "Text")
        ]
    }

    var todayTasks: [TaskPreview] {
        [
            TaskPreview(title: "Apply to Airbnb", nextAction: "Open the job description", status: .calendarPending),
            TaskPreview(title: "Update resume", nextAction: "Review the summary section", status: .notScheduled),
            TaskPreview(title: "Call dentist", nextAction: "Find the saved phone number", status: .overdue)
        ]
    }

    var inboxItems: [TaskPreview] {
        [
            TaskPreview(title: "Work on portfolio", nextAction: "Pick the first project to polish", status: .notScheduled),
            TaskPreview(title: "Weekend plan ideas", nextAction: "Decide if this becomes a task", status: .needsDecision)
        ]
    }
}

struct ParserServiceStub {
    var modeLabel: String { "Rule-based placeholder" }
}

struct CalendarServiceStub {
    var connectionLabel: String { "Disconnected" }
}

struct NotificationServiceStub {
    var permissionLabel: String { "Not requested" }
}

struct CapturePreview: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let source: String
}

struct TaskPreview: Identifiable {
    let id = UUID()
    let title: String
    let nextAction: String
    let status: DLStatus
}
