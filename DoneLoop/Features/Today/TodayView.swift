import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var services: AppServices
    let showTaskDetail: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DLSpacing.xl) {
                HStack {
                    VStack(alignment: .leading, spacing: DLSpacing.xs) {
                        Text(Date.now, style: .date)
                            .font(.callout)
                            .foregroundStyle(DLColor.textSecondary)
                        Text("Top 3")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(DLColor.textPrimary)
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "mic.fill")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.white)
                            .background(DLColor.primary, in: Circle())
                    }
                    .accessibilityLabel("Quick capture")
                }

                ForEach(services.localStore.todayTasks.prefix(3)) { task in
                    Button(action: showTaskDetail) {
                        DLTaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: DLSpacing.md) {
                    Text("Calendar Blocks")
                        .font(.headline)
                    DLEmptyState(
                        title: "Calendar disconnected",
                        detail: "Scheduled work will stay local until Google Calendar is connected.",
                        systemImage: "calendar.badge.exclamationmark"
                    )
                }
            }
            .padding(DLSpacing.lg)
        }
        .background(DLColor.background)
        .navigationTitle("Today")
    }
}
