import SwiftUI

struct ReminderDecisionSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let actions: [(title: String, symbol: String, status: DLStatus)] = [
        ("Done", "checkmark", .done),
        ("Snooze", "clock", .notScheduled),
        ("Reschedule", "calendar.badge.clock", .calendarPending),
        ("Break down", "list.bullet.indent", .needsDecision),
        ("Blocked", "exclamationmark.octagon", .blocked),
        ("Delete", "trash", .calendarFailed)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DLSpacing.xl) {
            VStack(alignment: .leading, spacing: DLSpacing.sm) {
                Text("Apply to Airbnb")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DLColor.textPrimary)
                Text("Next action: Open the job description.")
                    .font(.callout)
                    .foregroundStyle(DLColor.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DLSpacing.md) {
                ForEach(actions, id: \.title) { action in
                    Button {
                        dismiss()
                    } label: {
                        Label(action.title, systemImage: action.symbol)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(action.status.foreground)
                            .background(action.status.background, in: RoundedRectangle(cornerRadius: DLRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("You have avoided this twice. Want me to shrink it?")
                .font(.callout)
                .foregroundStyle(DLColor.attention)
                .padding(DLSpacing.md)
                .background(DLColor.attentionMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
        }
        .padding(DLSpacing.lg)
        .background(DLColor.background)
    }
}
