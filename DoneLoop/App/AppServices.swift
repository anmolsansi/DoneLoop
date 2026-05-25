import Foundation
import Combine

@MainActor
final class AppServices: ObservableObject {
    let localStore = LocalStore()
    let aiRouter = AIProviderRouter()
    let calendar = CalendarService()
    let notifications = NotificationService()

    private var cancellables: Set<AnyCancellable> = []

    init() {
        localStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        aiRouter.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        calendar.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        notifications.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var parserModeLabel: String {
        aiRouter.modeDetail(for: localStore.settings)
    }
}
