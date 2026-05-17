import Foundation

@MainActor
final class AppServices: ObservableObject {
    let localStore = LocalStore()
    let aiRouter = AIProviderRouter()
    let calendar = CalendarServiceStub()
    let notifications = NotificationServiceStub()

    var parserModeLabel: String {
        aiRouter.modeDetail(for: localStore.settings)
    }
}

struct CalendarServiceStub {
    var connectionLabel: String { "Disconnected" }
}

struct NotificationServiceStub {
    var permissionLabel: String { "Not requested" }
}
