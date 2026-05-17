import Foundation

enum DLParserIntent: String, Codable, CaseIterable {
    case createItems
    case rescheduleTask
    case markDone
    case breakDownTask
}

enum DLParsedItemType: String, Codable, CaseIterable {
    case task
    case reminder
    case calendarBlock
    case note
    case idea
    case brainDump
}

struct DLParserOutput: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var intent: DLParserIntent
    var sourceCaptureID: UUID?
    var confidence: Double
    var items: [DLParsedItem]
    var warnings: [String]

    init(
        schemaVersion: Int = DLParserOutput.currentSchemaVersion,
        intent: DLParserIntent = .createItems,
        sourceCaptureID: UUID? = nil,
        confidence: Double,
        items: [DLParsedItem],
        warnings: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.intent = intent
        self.sourceCaptureID = sourceCaptureID
        self.confidence = confidence
        self.items = items
        self.warnings = warnings
    }

    func validationErrors() -> [String] {
        var errors: [String] = []

        if schemaVersion != Self.currentSchemaVersion {
            errors.append("Unsupported parser schema version.")
        }

        if confidence < 0 || confidence > 1 {
            errors.append("Confidence must be between 0 and 1.")
        }

        if items.isEmpty {
            errors.append("Parser output must include at least one item.")
        }

        for item in items {
            errors.append(contentsOf: item.validationErrors())
        }

        return errors
    }

    var isValid: Bool {
        validationErrors().isEmpty
    }
}

struct DLParsedItem: Codable, Equatable, Identifiable {
    var id: UUID
    var type: DLParsedItemType
    var title: String
    var summary: String?
    var nextAction: String?
    var category: String?
    var priority: DLTaskPriority
    var dueDate: Date?
    var dueTime: Date?
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var calendarRequired: Bool
    var confidence: Double
    var needsClarification: Bool
    var warnings: [String]

    init(
        id: UUID = UUID(),
        type: DLParsedItemType,
        title: String,
        summary: String? = nil,
        nextAction: String? = nil,
        category: String? = nil,
        priority: DLTaskPriority = .normal,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        scheduledStart: Date? = nil,
        scheduledEnd: Date? = nil,
        calendarRequired: Bool = false,
        confidence: Double = 0.7,
        needsClarification: Bool = false,
        warnings: [String] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.summary = summary
        self.nextAction = nextAction
        self.category = category
        self.priority = priority
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.calendarRequired = calendarRequired
        self.confidence = confidence
        self.needsClarification = needsClarification
        self.warnings = warnings
    }

    func validationErrors() -> [String] {
        var errors: [String] = []
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            errors.append("Every parsed item needs a title.")
        }

        if confidence < 0 || confidence > 1 {
            errors.append("Item confidence must be between 0 and 1.")
        }

        if let scheduledStart, let scheduledEnd, scheduledEnd <= scheduledStart {
            errors.append("Scheduled end must be after scheduled start.")
        }

        if calendarRequired && scheduledStart == nil {
            errors.append("Calendar items must include a scheduled start.")
        }

        return errors
    }
}

enum DLParserSampleData {
    static let validOutputs: [DLParserOutput] = [
        DLParserOutput(
            confidence: 0.88,
            items: [
                DLParsedItem(
                    type: .task,
                    title: "Apply to Airbnb",
                    summary: "Submit an application for the Airbnb role.",
                    nextAction: "Open the Airbnb job description.",
                    category: "job_search",
                    priority: .high,
                    confidence: 0.9
                )
            ]
        ),
        DLParserOutput(
            confidence: 0.78,
            items: [
                DLParsedItem(
                    type: .note,
                    title: "Resume feedback",
                    summary: "Capture notes about improving the resume summary.",
                    confidence: 0.82
                )
            ]
        ),
        DLParserOutput(
            confidence: 0.8,
            items: [
                DLParsedItem(
                    type: .reminder,
                    title: "Call dentist",
                    nextAction: "Find the saved phone number.",
                    dueDate: Date(),
                    confidence: 0.8
                )
            ]
        ),
        DLParserOutput(
            confidence: 0.86,
            items: [
                DLParsedItem(
                    type: .calendarBlock,
                    title: "Job application work",
                    scheduledStart: Date(),
                    scheduledEnd: Date().addingTimeInterval(3600),
                    calendarRequired: true,
                    confidence: 0.86
                )
            ]
        ),
        DLParserOutput(
            confidence: 0.65,
            items: [
                DLParsedItem(
                    type: .brainDump,
                    title: "Unsorted thoughts",
                    summary: "Needs cleanup before creating tasks.",
                    needsClarification: true,
                    warnings: ["Brain dump needs review before saving work items."]
                )
            ],
            warnings: ["Low structure input."]
        )
    ]

    static let invalidOutputs: [DLParserOutput] = [
        DLParserOutput(confidence: 0.8, items: []),
        DLParserOutput(
            confidence: 1.4,
            items: [DLParsedItem(type: .task, title: "Invalid confidence")]
        ),
        DLParserOutput(
            confidence: 0.5,
            items: [DLParsedItem(type: .calendarBlock, title: "Missing time", calendarRequired: true)]
        ),
        DLParserOutput(
            schemaVersion: 999,
            confidence: 0.5,
            items: [DLParsedItem(type: .task, title: "Wrong schema")]
        )
    ]
}
