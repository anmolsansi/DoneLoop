import SwiftUI

struct AppRootView: View {
    @State private var selectedTab: AppTab = .capture
    @State private var isShowingTaskDetail = false
    @State private var isShowingDecisionSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CaptureView(
                    showTaskDetail: { isShowingTaskDetail = true },
                    showDecisionSheet: { isShowingDecisionSheet = true },
                    showToday: { selectedTab = .today },
                    showInbox: { selectedTab = .inbox }
                )
            }
            .tabItem { Label(AppTab.capture.title, systemImage: AppTab.capture.symbol) }
            .tag(AppTab.capture)

            NavigationStack {
                TodayView(
                    showTaskDetail: { isShowingTaskDetail = true },
                    showCapture: { selectedTab = .capture }
                )
            }
            .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.symbol) }
            .tag(AppTab.today)

            NavigationStack {
                InboxView(showTaskDetail: { isShowingTaskDetail = true })
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
        .sheet(isPresented: $isShowingTaskDetail) {
            NavigationStack {
                TaskDetailPlaceholderView(showDecisionSheet: {
                    isShowingTaskDetail = false
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

struct AppRootView_Previews: PreviewProvider {
    static var previews: some View {
        AppRootView()
            .environmentObject(AppServices())
    }
}
