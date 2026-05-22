import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var services: AppServices
    @State private var selectedTab: AppTab = .capture
    @State private var selectedTask: SelectedTask?
    @State private var decisionTask: SelectedTask?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CaptureView(
                    showTaskDetail: {
                        if let taskID = services.localStore.tasks.first?.id {
                            selectedTask = SelectedTask(id: taskID)
                        }
                    },
                    showDecisionSheet: { showDecisionSheetForFirstTask() },
                    showToday: { selectedTab = .today },
                    showInbox: { selectedTab = .inbox }
                )
            }
            .tabItem { Label(AppTab.capture.title, systemImage: AppTab.capture.symbol) }
            .tag(AppTab.capture)

            NavigationStack {
                TodayView(
                    showTaskDetail: { selectedTask = SelectedTask(id: $0) },
                    showCapture: { selectedTab = .capture }
                )
            }
            .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.symbol) }
            .tag(AppTab.today)

            NavigationStack {
                InboxView(showTaskDetail: { selectedTask = SelectedTask(id: $0) })
            }
            .tabItem { Label(AppTab.inbox.title, systemImage: AppTab.inbox.symbol) }
            .tag(AppTab.inbox)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
            .tag(AppTab.settings)
        }
        .tint(DLColor.primary)
        .sheet(item: $selectedTask) { selectedTask in
            NavigationStack {
                TaskDetailPlaceholderView(taskID: selectedTask.id, showDecisionSheet: {
                    decisionTask = selectedTask
                    self.selectedTask = nil
                })
            }
            .presentationDetents([.large])
        }
        .sheet(item: $decisionTask) { selectedTask in
            ReminderDecisionSheet(taskID: selectedTask.id)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            services.notifications.refreshAuthorizationStatus(store: services.localStore)
        }
        .onChange(of: services.notifications.openedTaskID) { _, taskID in
            guard let taskID else { return }
            if let task = services.localStore.task(id: taskID), task.status != .done && task.status != .deleted {
                selectedTab = .today
                selectedTask = nil
                decisionTask = SelectedTask(id: taskID)
            } else {
                selectedTab = .today
            }
            services.notifications.consumeOpenedTaskID()
        }
    }

    private func showDecisionSheetForFirstTask() {
        guard let task = services.localStore.tasks.first(where: { $0.status != .done && $0.status != .deleted }) else { return }
        decisionTask = SelectedTask(id: task.id)
    }
}

private struct SelectedTask: Identifiable {
    let id: UUID
}

struct AppRootView_Previews: PreviewProvider {
    static var previews: some View {
        AppRootView()
            .environmentObject(AppServices())
    }
}
