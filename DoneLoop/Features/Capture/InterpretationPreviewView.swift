import SwiftUI

struct InterpretationPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: AppServices

    let output: DLParserOutput?
    let errorMessage: String?
    let isParsing: Bool
    let retry: () -> Void
    let showTaskDetail: () -> Void
    let showToday: () -> Void
    let showInbox: () -> Void

    @State private var items: [DLParsedItem]
    @State private var creationResult: DLCreationResult?
    @State private var saveErrors: [DLValidationIssue] = []

    init(
        output: DLParserOutput?,
        errorMessage: String?,
        isParsing: Bool,
        retry: @escaping () -> Void,
        showTaskDetail: @escaping () -> Void,
        showToday: @escaping () -> Void,
        showInbox: @escaping () -> Void
    ) {
        self.output = output
        self.errorMessage = errorMessage
        self.isParsing = isParsing
        self.retry = retry
        self.showTaskDetail = showTaskDetail
        self.showToday = showToday
        self.showInbox = showInbox
        self._items = State(initialValue: output?.items ?? [])
    }

    private var currentOutput: DLParserOutput? {
        guard let output else { return nil }
        var editedOutput = output
        editedOutput.items = items
        return editedOutput
    }

    private var validationResult: DLParserValidationResult {
        guard let currentOutput else {
            return DLParserValidationResult(issues: [])
        }
        return DLParserOutputValidator.validate(currentOutput)
    }

    private var canSave: Bool {
        !isParsing && errorMessage == nil && currentOutput != nil && validationResult.canSave && creationResult == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DLSpacing.lg) {
                    header

                    if isParsing {
                        ProgressView("Parsing locally...")
                            .frame(maxWidth: .infinity)
                            .padding(DLSpacing.xl)
                            .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
                    } else if let errorMessage {
                        errorCard(errorMessage)
                    } else if let creationResult {
                        confirmationView(creationResult)
                    } else if items.isEmpty {
                        emptyOutput
                    } else {
                        warningsView
                        groupedItems
                        validationView
                    }

                    if creationResult == nil {
                        HStack(spacing: DLSpacing.md) {
                            Button("Try Again", action: retry)
                                .buttonStyle(.bordered)
                            Spacer()
                            DLPrimaryButton("Save Items", systemImage: "tray.and.arrow.down") {
                                saveItems()
                            }
                            .disabled(!canSave)
                        }
                    }
                }
                .padding(DLSpacing.lg)
            }
            .background(DLColor.background)
            .navigationTitle("Interpretation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
            }
        }
        .onChange(of: output) { _, newOutput in
            items = newOutput?.items ?? []
            creationResult = nil
            saveErrors = []
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DLSpacing.sm) {
            Text("Review before saving")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DLColor.textPrimary)
            Text("Parsed locally with the rule-based fallback. Nothing becomes a task, note, reminder, or calendar block until you save.")
                .font(.callout)
                .foregroundStyle(DLColor.textSecondary)
        }
    }

    private var warningsView: some View {
        VStack(alignment: .leading, spacing: DLSpacing.xs) {
            if let output, !output.warnings.isEmpty {
                ForEach(output.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(DLColor.attention)
                }
            }
        }
    }

    private var groupedItems: some View {
        VStack(alignment: .leading, spacing: DLSpacing.lg) {
            ForEach(DLParsedItemType.allCases, id: \.self) { type in
                let indices = items.indices.filter { items[$0].type == type }
                if !indices.isEmpty {
                    VStack(alignment: .leading, spacing: DLSpacing.sm) {
                        Text(type.displayName)
                            .font(.headline)
                            .foregroundStyle(DLColor.textPrimary)

                        ForEach(indices, id: \.self) { index in
                            itemCard(item: $items[index])
                        }
                    }
                }
            }
        }
    }

    private var validationView: some View {
        VStack(alignment: .leading, spacing: DLSpacing.xs) {
            ForEach(validationResult.blockingIssues) { issue in
                validationRow(issue, systemImage: "xmark.octagon", color: DLColor.danger)
            }
            ForEach(validationResult.clarificationIssues) { issue in
                validationRow(issue, systemImage: "questionmark.circle", color: DLColor.attention)
            }
            ForEach(validationResult.warningIssues) { issue in
                validationRow(issue, systemImage: "exclamationmark.triangle", color: DLColor.attention)
            }
            ForEach(saveErrors) { issue in
                validationRow(issue, systemImage: "xmark.octagon", color: DLColor.danger)
            }
        }
    }

    private func validationRow(_ issue: DLValidationIssue, systemImage: String, color: Color) -> some View {
        Label(issue.message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
    }

    private var emptyOutput: some View {
        DLEmptyState(
            title: "No items to save",
            detail: "Try again or cancel this preview.",
            systemImage: "tray"
        )
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.sm) {
            Label("Parsing failed", systemImage: "xmark.octagon")
                .font(.headline)
                .foregroundStyle(DLColor.danger)
            Text(message)
                .font(.callout)
                .foregroundStyle(DLColor.textSecondary)
        }
        .padding(DLSpacing.md)
        .background(DLColor.dangerMuted, in: RoundedRectangle(cornerRadius: DLRadius.md))
    }

    private func confirmationView(_ result: DLCreationResult) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.lg) {
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DLColor.success)

            Text(result.confirmationMessage)
                .font(.callout)
                .foregroundStyle(DLColor.textSecondary)

            ForEach(result.createdItems) { item in
                HStack(spacing: DLSpacing.md) {
                    Image(systemName: item.type.systemImage)
                        .foregroundStyle(DLColor.primary)
                    VStack(alignment: .leading, spacing: DLSpacing.xs) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(DLColor.textPrimary)
                        Text(item.destination.displayName)
                            .font(.caption)
                            .foregroundStyle(DLColor.textSecondary)
                    }
                    Spacer()
                }
            }

            HStack(spacing: DLSpacing.md) {
                Button {
                    dismiss()
                    showInbox()
                } label: {
                    Label("Open Inbox", systemImage: "tray")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                DLPrimaryButton("Open Today", systemImage: "sun.max") {
                    dismiss()
                    showToday()
                }
            }
        }
        .padding(DLSpacing.md)
        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DLRadius.md)
                .stroke(DLColor.divider, lineWidth: 0.5)
        )
    }

    private func itemCard(item: Binding<DLParsedItem>) -> some View {
        VStack(alignment: .leading, spacing: DLSpacing.md) {
            HStack {
                Label(item.wrappedValue.type.displayName, systemImage: item.wrappedValue.type.systemImage)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, DLSpacing.sm)
                    .padding(.vertical, DLSpacing.xs)
                    .background(DLColor.infoMuted, in: Capsule())
                    .foregroundStyle(DLColor.info)

                if item.wrappedValue.calendarRequired {
                    Label("Calendar", systemImage: "calendar.badge.clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DLColor.attention)
                }

                Spacer()

                Button(role: .destructive) {
                    items.removeAll { $0.id == item.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Remove item")
            }

            TextField("Title", text: item.title)
                .textFieldStyle(.roundedBorder)

            TextField("Next action", text: optionalText(item.nextAction, defaultValue: ""))
                .textFieldStyle(.roundedBorder)

            if let scheduleText = scheduleText(for: item.wrappedValue) {
                Label(scheduleText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(DLColor.textSecondary)
            }

            if item.wrappedValue.needsClarification {
                Label("Needs clarification", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(DLColor.attention)
            }

            Text("Confidence \(Int(item.wrappedValue.confidence * 100))%")
                .font(.caption)
                .foregroundStyle(DLColor.textTertiary)

            ForEach(item.wrappedValue.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(DLColor.attention)
            }
        }
        .padding(DLSpacing.md)
        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DLRadius.md)
                .stroke(DLColor.divider, lineWidth: 0.5)
        )
    }

    private func saveItems() {
        guard let output = currentOutput else { return }
        let validation = DLParserOutputValidator.validate(output)
        let result = DLItemCreationEngine.createItems(
            from: output,
            validation: validation,
            in: services.localStore
        )

        switch result {
        case .success(let creationResult):
            services.calendar.syncScheduledTasks(in: services.localStore)
            services.notifications.scheduleAllEligibleTasks(in: services.localStore)
            self.creationResult = creationResult
            self.saveErrors = []
        case .failure(.validation(let issues)):
            self.saveErrors = issues
        }
    }

    private func optionalText(_ binding: Binding<String?>, defaultValue: String) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue ?? defaultValue },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                binding.wrappedValue = trimmed.isEmpty ? nil : newValue
            }
        )
    }

    private func scheduleText(for item: DLParsedItem) -> String? {
        if let scheduledStart = item.scheduledStart {
            if let scheduledEnd = item.scheduledEnd {
                return "\(scheduledStart.formatted(date: .abbreviated, time: .shortened)) to \(scheduledEnd.formatted(date: .omitted, time: .shortened))"
            }
            return scheduledStart.formatted(date: .abbreviated, time: .shortened)
        }

        if let dueDate = item.dueDate {
            return dueDate.formatted(date: .abbreviated, time: .shortened)
        }

        return nil
    }
}

private extension DLCreatedItemDestination {
    var displayName: String {
        switch self {
        case .today: "Today"
        case .scheduled: "Scheduled"
        case .inbox: "Inbox"
        case .notes: "Notes"
        case .ideas: "Ideas"
        }
    }
}

private extension DLParsedItemType {
    var displayName: String {
        switch self {
        case .task: "Task"
        case .reminder: "Reminder"
        case .calendarBlock: "Calendar Block"
        case .note: "Note"
        case .idea: "Idea"
        case .brainDump: "Brain Dump"
        }
    }

    var systemImage: String {
        switch self {
        case .task: "checkmark.circle"
        case .reminder: "bell"
        case .calendarBlock: "calendar"
        case .note: "note.text"
        case .idea: "lightbulb"
        case .brainDump: "tray.full"
        }
    }
}
