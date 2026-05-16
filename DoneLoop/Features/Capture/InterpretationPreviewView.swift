import SwiftUI

struct InterpretationPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let showTaskDetail: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DLSpacing.lg) {
                Text("Review before saving")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DLColor.textPrimary)

                DLTaskRow(
                    task: TaskPreview(
                        title: "Apply to Airbnb",
                        nextAction: "Open the Airbnb job description",
                        status: .calendarPending
                    )
                )

                VStack(alignment: .leading, spacing: DLSpacing.sm) {
                    Label("Calendar block required", systemImage: "calendar.badge.clock")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DLColor.info)
                    Text("Tomorrow, 10:00 AM to 11:00 AM")
                        .font(.callout)
                        .foregroundStyle(DLColor.textSecondary)
                }
                .padding(DLSpacing.md)
                .background(DLColor.infoMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))

                Spacer()

                DLPrimaryButton("Save Items", systemImage: "tray.and.arrow.down") {
                    dismiss()
                    showTaskDetail()
                }
            }
            .padding(DLSpacing.lg)
            .background(DLColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
            }
        }
    }
}
