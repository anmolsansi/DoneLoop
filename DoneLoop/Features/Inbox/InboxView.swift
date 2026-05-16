import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var services: AppServices
    let showTaskDetail: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DLSpacing.xl) {
                inboxSection(title: "Unscheduled Tasks", items: services.localStore.inboxItems)
                inboxSection(title: "Needs Clarification", items: [
                    TaskPreview(
                        title: "Work on resume",
                        nextAction: "When do you want to work on this?",
                        status: .needsDecision
                    )
                ])
                DLEmptyState(
                    title: "Notes and ideas are quiet.",
                    detail: "Captured notes, ideas, and brain dumps will appear here when they do not belong on Today.",
                    systemImage: "tray"
                )
            }
            .padding(DLSpacing.lg)
        }
        .background(DLColor.background)
        .navigationTitle("Inbox")
    }

    private func inboxSection(title: String, items: [TaskPreview]) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)

            ForEach(items) { item in
                Button(action: showTaskDetail) {
                    DLTaskRow(task: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
