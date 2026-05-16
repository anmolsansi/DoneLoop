import SwiftUI

enum DLColor {
    static let background = Color(red: 0.973, green: 0.965, blue: 0.941)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.945, green: 0.933, blue: 0.902)
    static let textPrimary = Color(red: 0.122, green: 0.141, blue: 0.129)
    static let textSecondary = Color(red: 0.369, green: 0.400, blue: 0.373)
    static let textTertiary = Color(red: 0.541, green: 0.573, blue: 0.549)
    static let divider = Color(red: 0.871, green: 0.855, blue: 0.816)
    static let primary = Color(red: 0.333, green: 0.486, blue: 0.392)
    static let primaryPressed = Color(red: 0.255, green: 0.384, blue: 0.302)
    static let primaryMuted = Color(red: 0.867, green: 0.914, blue: 0.882)
    static let attention = Color(red: 0.718, green: 0.475, blue: 0.122)
    static let attentionMuted = Color(red: 0.969, green: 0.906, blue: 0.773)
    static let success = Color(red: 0.184, green: 0.490, blue: 0.310)
    static let successMuted = Color(red: 0.863, green: 0.925, blue: 0.875)
    static let danger = Color(red: 0.725, green: 0.275, blue: 0.247)
    static let dangerMuted = Color(red: 0.957, green: 0.855, blue: 0.843)
    static let info = Color(red: 0.294, green: 0.435, blue: 0.565)
    static let infoMuted = Color(red: 0.863, green: 0.906, blue: 0.937)
}

enum DLSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum DLRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let full: CGFloat = 999
}

enum DLStatus {
    case done
    case overdue
    case blocked
    case needsDecision
    case calendarPending
    case calendarSynced
    case calendarFailed
    case calendarDisconnected
    case notScheduled

    var title: String {
        switch self {
        case .done: "Done"
        case .overdue: "Overdue"
        case .blocked: "Blocked"
        case .needsDecision: "Needs decision"
        case .calendarPending: "Calendar pending"
        case .calendarSynced: "Synced"
        case .calendarFailed: "Sync failed"
        case .calendarDisconnected: "Disconnected"
        case .notScheduled: "Not scheduled"
        }
    }

    var foreground: Color {
        switch self {
        case .done, .calendarSynced: DLColor.success
        case .overdue, .blocked, .needsDecision: DLColor.attention
        case .calendarFailed: DLColor.danger
        case .calendarPending, .calendarDisconnected, .notScheduled: DLColor.info
        }
    }

    var background: Color {
        switch self {
        case .done, .calendarSynced: DLColor.successMuted
        case .overdue, .blocked, .needsDecision: DLColor.attentionMuted
        case .calendarFailed: DLColor.dangerMuted
        case .calendarPending, .calendarDisconnected, .notScheduled: DLColor.infoMuted
        }
    }
}

struct DLStatusBadge: View {
    let status: DLStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.foreground)
            .padding(.horizontal, DLSpacing.sm)
            .padding(.vertical, DLSpacing.xs)
            .background(status.background, in: Capsule())
    }
}

struct DLPrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "checkmark")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DLSpacing.md)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(DLColor.primary, in: RoundedRectangle(cornerRadius: DLRadius.md))
    }
}

struct DLTaskRow: View {
    let task: TaskPreview

    var body: some View {
        HStack(alignment: .top, spacing: DLSpacing.md) {
            VStack(alignment: .leading, spacing: DLSpacing.xs) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(DLColor.textPrimary)
                    .lineLimit(2)
                Text(task.nextAction)
                    .font(.callout)
                    .foregroundStyle(DLColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: DLSpacing.sm)
            DLStatusBadge(status: task.status)
        }
        .padding(DLSpacing.md)
        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DLRadius.md)
                .stroke(DLColor.divider, lineWidth: 0.5)
        )
    }
}

struct DLEmptyState: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(spacing: DLSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(DLColor.primary)
            Text(title)
                .font(.headline)
                .foregroundStyle(DLColor.textPrimary)
            Text(detail)
                .font(.callout)
                .foregroundStyle(DLColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DLSpacing.xl)
        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DLRadius.md)
                .stroke(DLColor.divider, lineWidth: 0.5)
        )
    }
}
