import Foundation

enum DLTaskStatus: String, Codable, CaseIterable {
    case inbox
    case scheduled
    case inProgress
    case done
    case snoozed
    case blocked
    case deleted
}

enum DLTaskPriority: String, Codable, CaseIterable {
    case low
    case normal
    case high
}

enum DLCaptureSource: String, Codable, CaseIterable {
    case voice
    case text
}

enum DLCaptureProcessingStatus: String, Codable, CaseIterable {
    case draft
    case readyToInterpret
    case saved
    case needsReview
    case failed

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .readyToInterpret: "Ready to interpret"
        case .saved: "Saved"
        case .needsReview: "Needs review"
        case .failed: "Failed"
        }
    }
}

enum DLAIProvider: String, Codable, CaseIterable {
    case none
    case local
    case ruleBased
    case cloudFallback
}

enum DLAIMode: String, Codable, CaseIterable {
    case localOnly
    case localWithFallback
    case bringYourOwnKey

    var displayName: String {
        switch self {
        case .localOnly: "Local Only"
        case .localWithFallback: "Local + Fallback"
        case .bringYourOwnKey: "Bring Your Own Key"
        }
    }
}

struct DLTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var summary: String?
    var nextAction: String?
    var status: DLTaskStatus
    var priority: DLTaskPriority
    var category: String?
    var dueDate: Date?
    var dueTime: Date?
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var calendarEventID: String?
    var snoozeCount: Int
    var missedCount: Int
    var sourceCaptureID: UUID?
    var source: DLCaptureSource?
    var aiProviderUsed: DLAIProvider
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        nextAction: String? = nil,
        status: DLTaskStatus = .inbox,
        priority: DLTaskPriority = .normal,
        category: String? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        scheduledStart: Date? = nil,
        scheduledEnd: Date? = nil,
        calendarEventID: String? = nil,
        snoozeCount: Int = 0,
        missedCount: Int = 0,
        sourceCaptureID: UUID? = nil,
        source: DLCaptureSource? = nil,
        aiProviderUsed: DLAIProvider = .none,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.nextAction = nextAction
        self.status = status
        self.priority = priority
        self.category = category
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.calendarEventID = calendarEventID
        self.snoozeCount = snoozeCount
        self.missedCount = missedCount
        self.sourceCaptureID = sourceCaptureID
        self.source = source
        self.aiProviderUsed = aiProviderUsed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DLCapture: Identifiable, Codable, Equatable {
    var id: UUID
    var rawText: String
    var audioFilePath: String?
    var transcript: String?
    var aiOutputJSON: String?
    var confidenceScore: Double?
    var source: DLCaptureSource
    var processingStatus: DLCaptureProcessingStatus
    var aiProviderUsed: DLAIProvider
    var createdAt: Date

    init(
        id: UUID = UUID(),
        rawText: String,
        audioFilePath: String? = nil,
        transcript: String? = nil,
        aiOutputJSON: String? = nil,
        confidenceScore: Double? = nil,
        source: DLCaptureSource,
        processingStatus: DLCaptureProcessingStatus = .readyToInterpret,
        aiProviderUsed: DLAIProvider = .none,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rawText = rawText
        self.audioFilePath = audioFilePath
        self.transcript = transcript
        self.aiOutputJSON = aiOutputJSON
        self.confidenceScore = confidenceScore
        self.source = source
        self.processingStatus = processingStatus
        self.aiProviderUsed = aiProviderUsed
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case rawText
        case audioFilePath
        case transcript
        case aiOutputJSON
        case confidenceScore
        case source
        case processingStatus
        case aiProviderUsed
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.rawText = try container.decode(String.self, forKey: .rawText)
        self.audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath)
        self.transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
        self.aiOutputJSON = try container.decodeIfPresent(String.self, forKey: .aiOutputJSON)
        self.confidenceScore = try container.decodeIfPresent(Double.self, forKey: .confidenceScore)
        self.source = try container.decode(DLCaptureSource.self, forKey: .source)
        self.processingStatus = try container.decodeIfPresent(DLCaptureProcessingStatus.self, forKey: .processingStatus) ?? .readyToInterpret
        self.aiProviderUsed = try container.decodeIfPresent(DLAIProvider.self, forKey: .aiProviderUsed) ?? .none
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct DLNote: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var summary: String?
    var category: String?
    var sourceCaptureID: UUID?
    var createdAt: Date
    var updatedAt: Date
}

struct DLIdea: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var summary: String?
    var suggestedNextAction: String?
    var convertedToTaskID: UUID?
    var createdAt: Date
    var updatedAt: Date
}

struct DLUserSettings: Codable, Equatable {
    var id: UUID
    var timezoneIdentifier: String
    var preferredWorkStartHour: Int
    var preferredWorkEndHour: Int
    var defaultTaskDurationMinutes: Int
    var aiMode: DLAIMode
    var remindersEnabled: Bool
    var localModelName: String?
    var cloudProvider: String?
    var googleCalendarID: String?
    var createdAt: Date
    var updatedAt: Date

    static func defaults(now: Date = Date()) -> DLUserSettings {
        DLUserSettings(
            id: UUID(),
            timezoneIdentifier: TimeZone.current.identifier,
            preferredWorkStartHour: 9,
            preferredWorkEndHour: 17,
            defaultTaskDurationMinutes: 30,
            aiMode: .localOnly,
            remindersEnabled: false,
            localModelName: nil,
            cloudProvider: nil,
            googleCalendarID: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case timezoneIdentifier
        case preferredWorkStartHour
        case preferredWorkEndHour
        case defaultTaskDurationMinutes
        case aiMode
        case remindersEnabled
        case localModelName
        case cloudProvider
        case googleCalendarID
        case createdAt
        case updatedAt
    }

    init(
        id: UUID,
        timezoneIdentifier: String,
        preferredWorkStartHour: Int,
        preferredWorkEndHour: Int,
        defaultTaskDurationMinutes: Int,
        aiMode: DLAIMode,
        remindersEnabled: Bool,
        localModelName: String?,
        cloudProvider: String?,
        googleCalendarID: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.timezoneIdentifier = timezoneIdentifier
        self.preferredWorkStartHour = preferredWorkStartHour
        self.preferredWorkEndHour = preferredWorkEndHour
        self.defaultTaskDurationMinutes = defaultTaskDurationMinutes
        self.aiMode = aiMode
        self.remindersEnabled = remindersEnabled
        self.localModelName = localModelName
        self.cloudProvider = cloudProvider
        self.googleCalendarID = googleCalendarID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let defaults = DLUserSettings.defaults()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? defaults.id
        self.timezoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timezoneIdentifier) ?? defaults.timezoneIdentifier
        self.preferredWorkStartHour = try container.decodeIfPresent(Int.self, forKey: .preferredWorkStartHour) ?? defaults.preferredWorkStartHour
        self.preferredWorkEndHour = try container.decodeIfPresent(Int.self, forKey: .preferredWorkEndHour) ?? defaults.preferredWorkEndHour
        self.defaultTaskDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultTaskDurationMinutes) ?? defaults.defaultTaskDurationMinutes
        self.aiMode = try container.decodeIfPresent(DLAIMode.self, forKey: .aiMode) ?? defaults.aiMode
        self.remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? defaults.remindersEnabled
        self.localModelName = try container.decodeIfPresent(String.self, forKey: .localModelName)
        self.cloudProvider = try container.decodeIfPresent(String.self, forKey: .cloudProvider)
        self.googleCalendarID = try container.decodeIfPresent(String.self, forKey: .googleCalendarID)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? defaults.createdAt
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? defaults.updatedAt
    }
}

struct CapturePreview: Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let source: String
    let status: String
    let timestamp: String
}

struct TaskPreview: Identifiable {
    let id: UUID
    let title: String
    let nextAction: String
    let status: DLStatus

    init(id: UUID = UUID(), title: String, nextAction: String, status: DLStatus) {
        self.id = id
        self.title = title
        self.nextAction = nextAction
        self.status = status
    }
}
