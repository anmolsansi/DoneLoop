import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var services: AppServices
    @State private var selectedTab: AppTab = .capture
    @State private var selectedTask: SelectedTask?
    @State private var decisionTask: SelectedTask?
    @State private var notificationFallback: NotificationFallback?
    @State private var isShowingOnboarding = false

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
        .sheet(isPresented: $isShowingOnboarding) {
            DLOnboardingView(
                finish: completeOnboarding,
                skip: completeOnboarding
            )
            .interactiveDismissDisabled()
        }
        .sheet(item: $selectedTask) { selectedTask in
            NavigationStack {
                TaskDetailView(taskID: selectedTask.id, showDecisionSheet: {
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
            isShowingOnboarding = !services.localStore.settings.hasCompletedOnboarding
            if let taskID = services.notifications.openedTaskID {
                routeNotificationTask(taskID)
            }
        }
        .onChange(of: services.localStore.settings.hasCompletedOnboarding) { _, hasCompleted in
            isShowingOnboarding = !hasCompleted
        }
        .onChange(of: services.notifications.openedTaskID) { _, taskID in
            guard let taskID else { return }
            routeNotificationTask(taskID)
        }
        .onChange(of: services.notifications.fallbackMessage) { _, message in
            guard let message else { return }
            selectedTab = .today
            notificationFallback = NotificationFallback(message: message)
            services.notifications.consumeFallbackMessage()
        }
        .alert(item: $notificationFallback) { fallback in
            Alert(
                title: Text("Reminder unavailable"),
                message: Text(fallback.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func showDecisionSheetForFirstTask() {
        guard let task = services.localStore.tasks.first(where: { $0.status != .done && $0.status != .deleted }) else { return }
        decisionTask = SelectedTask(id: task.id)
    }

    private func routeNotificationTask(_ taskID: UUID) {
        if let task = services.localStore.task(id: taskID), task.status != .done && task.status != .deleted {
            selectedTab = .today
            selectedTask = nil
            decisionTask = SelectedTask(id: taskID)
        } else {
            selectedTab = .today
            notificationFallback = NotificationFallback(
                message: "This reminder points to a task that is already done or deleted."
            )
        }
        services.notifications.consumeOpenedTaskID()
    }

    private func completeOnboarding() {
        services.localStore.completeOnboarding()
        isShowingOnboarding = false
    }
}

struct DLOnboardingView: View {
    let finish: () -> Void
    let skip: () -> Void

    private let items: [(title: String, detail: String, systemImage: String)] = [
        (
            "Capture messy thoughts",
            "Use voice or text. DoneLoop turns the capture into tasks, reminders, notes, ideas, or brain dumps before you save.",
            "mic.fill"
        ),
        (
            "Today stays small",
            "Inbox holds vague work. Today surfaces only the top few things that need attention, plus scheduled blocks.",
            "sun.max"
        ),
        (
            "Calendar is for time",
            "Only scheduled work belongs on Calendar. Notes, ideas, vague tasks, and brain dumps stay local.",
            "calendar.badge.clock"
        ),
        (
            "Reminders force a choice",
            "When a reminder fires, choose Done, Snooze, Reschedule, Break down, Blocked, or Delete.",
            "checklist"
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DLSpacing.xl) {
                    VStack(alignment: .leading, spacing: DLSpacing.sm) {
                        Text("DoneLoop")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(DLColor.textPrimary)
                        Text("A local-first task and memory loop. No permission is requested here; connect features later when you need them.")
                            .font(.callout)
                            .foregroundStyle(DLColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(items, id: \.title) { item in
                        HStack(alignment: .top, spacing: DLSpacing.md) {
                            Image(systemName: item.systemImage)
                                .foregroundStyle(DLColor.primary)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: DLSpacing.xs) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(DLColor.textPrimary)
                                Text(item.detail)
                                    .font(.callout)
                                    .foregroundStyle(DLColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(DLSpacing.md)
                        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DLRadius.md)
                                .stroke(DLColor.divider, lineWidth: 0.5)
                        )
                    }

                    DLPrimaryButton("Start Capturing", systemImage: "arrow.right") {
                        finish()
                    }
                }
                .padding(DLSpacing.lg)
            }
            .background(DLColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip", action: skip)
                }
            }
        }
    }
}

private struct SelectedTask: Identifiable {
    let id: UUID
}

private struct NotificationFallback: Identifiable {
    let id = UUID()
    let message: String
}

struct AppRootView_Previews: PreviewProvider {
    static var previews: some View {
        AppRootView()
            .environmentObject(AppServices())
    }
}
