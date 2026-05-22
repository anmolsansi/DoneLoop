import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var services: AppServices
    @State private var selectedTab: AppTab = .capture
    @State private var selectedTask: SelectedTask?
    @State private var isShowingDecisionSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CaptureView(
                    showTaskDetail: {
                        if let taskID = services.localStore.tasks.first?.id {
                            selectedTask = SelectedTask(id: taskID)
                        }
                    },
                    showDecisionSheet: { isShowingDecisionSheet = true },
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
                    self.selectedTask = nil
                    isShowingDecisionSheet = true
                })
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingDecisionSheet) {
            ReminderDecisionSheet()
                .presentationDetents([.medium, .large])
        }
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
