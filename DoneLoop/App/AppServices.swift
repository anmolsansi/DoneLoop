import Foundation

@MainActor
final class AppServices: ObservableObject {
    let localStore = LocalStore()
    let aiRouter = AIProviderRouter()
    let calendar = CalendarService()
    let notifications = NotificationServiceStub()

    var parserModeLabel: String {
        aiRouter.modeDetail(for: localStore.settings)
    }
}

struct NotificationServiceStub {
    var permissionLabel: String { "Not requested" }
}
