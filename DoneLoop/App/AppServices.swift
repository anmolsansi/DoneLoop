import Foundation

@MainActor
final class AppServices: ObservableObject {
    let localStore = LocalStore()
    let parser = ParserServiceStub()
    let calendar = CalendarServiceStub()
    let notifications = NotificationServiceStub()
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
