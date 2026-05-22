import Foundation

@MainActor
final class AppServices: ObservableObject {
    let localStore = LocalStore()
    let aiRouter = AIProviderRouter()
    let calendar = CalendarService()
    let notifications = NotificationService()

    var parserModeLabel: String {
        aiRouter.modeDetail(for: localStore.settings)
    }
}
