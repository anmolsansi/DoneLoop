import SwiftUI

struct TaskDetailPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    let showDecisionSheet: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DLSpacing.xl) {
                VStack(alignment: .leading, spacing: DLSpacing.sm) {
                    Text("Apply to Airbnb")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DLColor.textPrimary)
                    Text("Submit the application for the Airbnb role.")
                        .font(.body)
                        .foregroundStyle(DLColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: DLSpacing.sm) {
                    Text("Next Action")
                        .font(.headline)
                    Text("Open the Airbnb job description and tailor the resume.")
                        .font(.body)
                        .foregroundStyle(DLColor.textPrimary)
                }

                HStack {
                    DLStatusBadge(status: .calendarPending)
                    DLStatusBadge(status: .needsDecision)
                }

                DLPrimaryButton("Open Decision Sheet", systemImage: "checklist") {
                    showDecisionSheet()
                }
            }
            .padding(DLSpacing.lg)
        }
        .background(DLColor.background)
        .navigationTitle("Task Detail")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}
