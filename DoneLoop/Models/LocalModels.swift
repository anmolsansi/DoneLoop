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

enum DLGoogleCalendarConnectionStatus: String, Codable, CaseIterable {
    case disconnected
    case developmentPlaceholder
    case connected
    case permissionDenied
    case tokenExpired
    case networkUnavailable

    var displayName: String {
        switch self {
        case .disconnected: "Disconnected"
        case .developmentPlaceholder: "Real sync unavailable"
        case .connected: "Connected"
        case .permissionDenied: "Permission denied"
        case .tokenExpired: "Reconnect required"
        case .networkUnavailable: "Network unavailable"
        }
    }
}

enum DLCalendarSyncStatus: String, Codable, CaseIterable {
    case notScheduled
    case disconnected
    case pending
    case synced
    case failed

    var displayName: String {
        switch self {
        case .notScheduled: "Not scheduled"
        case .disconnected: "Disconnected"
        case .pending: "Calendar pending"
        case .synced: "Synced"
        case .failed: "Sync failed"
        }
    }
}

enum DLNotificationPermissionStatus: String, Codable, CaseIterable {
    case notDetermined
    case granted
    case denied
    case provisional

    var displayName: String {
        switch self {
        case .notDetermined: "Not requested"
        case .granted: "Allowed"
        case .denied: "Denied"
        case .provisional: "Quiet delivery"
        }
    }
}

enum DLNotificationScheduleStatus: String, Codable, CaseIterable {
    case notScheduled
    case pendingPermission
    case scheduled
    case permissionDenied
    case failed

    var displayName: String {
        switch self {
        case .notScheduled: "No reminder"
        case .pendingPermission: "Permission needed"
        case .scheduled: "Reminder scheduled"
        case .permissionDenied: "Reminders denied"
        case .failed: "Reminder failed"
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
    var calendarSyncStatus: DLCalendarSyncStatus
    var calendarSyncError: String?
    var notificationID: String?
    var notificationStatus: DLNotificationScheduleStatus
    var notificationError: String?
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
        calendarSyncStatus: DLCalendarSyncStatus = .notScheduled,
        calendarSyncError: String? = nil,
        notificationID: String? = nil,
        notificationStatus: DLNotificationScheduleStatus = .notScheduled,
        notificationError: String? = nil,
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
        self.calendarSyncStatus = calendarSyncStatus
        self.calendarSyncError = calendarSyncError
        self.notificationID = notificationID
        self.notificationStatus = notificationStatus
        self.notificationError = notificationError
        self.snoozeCount = snoozeCount
        self.missedCount = missedCount
        self.sourceCaptureID = sourceCaptureID
        self.source = source
        self.aiProviderUsed = aiProviderUsed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case nextAction
        case status
        case priority
        case category
        case dueDate
        case dueTime
        case scheduledStart
        case scheduledEnd
        case calendarEventID
        case calendarSyncStatus
        case calendarSyncError
        case notificationID
        case notificationStatus
        case notificationError
        case snoozeCount
        case missedCount
        case sourceCaptureID
        case source
        case aiProviderUsed
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
        self.nextAction = try container.decodeIfPresent(String.self, forKey: .nextAction)
        self.status = try container.decode(DLTaskStatus.self, forKey: .status)
        self.priority = try container.decode(DLTaskPriority.self, forKey: .priority)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        self.dueTime = try container.decodeIfPresent(Date.self, forKey: .dueTime)
        self.scheduledStart = try container.decodeIfPresent(Date.self, forKey: .scheduledStart)
        self.scheduledEnd = try container.decodeIfPresent(Date.self, forKey: .scheduledEnd)
        self.calendarEventID = try container.decodeIfPresent(String.self, forKey: .calendarEventID)
        self.calendarSyncStatus = try container.decodeIfPresent(DLCalendarSyncStatus.self, forKey: .calendarSyncStatus)
            ?? (self.calendarEventID == nil ? .notScheduled : .synced)
        self.calendarSyncError = try container.decodeIfPresent(String.self, forKey: .calendarSyncError)
        self.notificationID = try container.decodeIfPresent(String.self, forKey: .notificationID)
        self.notificationStatus = try container.decodeIfPresent(DLNotificationScheduleStatus.self, forKey: .notificationStatus)
            ?? (self.notificationID == nil ? .notScheduled : .scheduled)
        self.notificationError = try container.decodeIfPresent(String.self, forKey: .notificationError)
        self.snoozeCount = try container.decode(Int.self, forKey: .snoozeCount)
        self.missedCount = try container.decode(Int.self, forKey: .missedCount)
        self.sourceCaptureID = try container.decodeIfPresent(UUID.self, forKey: .sourceCaptureID)
        self.source = try container.decodeIfPresent(DLCaptureSource.self, forKey: .source)
        self.aiProviderUsed = try container.decode(DLAIProvider.self, forKey: .aiProviderUsed)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
    var googleCalendarAccountEmail: String?
    var googleCalendarName: String?
    var googleCalendarConnectionStatus: DLGoogleCalendarConnectionStatus
    var notificationPermissionStatus: DLNotificationPermissionStatus
    var defaultSnoozeMinutes: Int
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
            googleCalendarAccountEmail: nil,
            googleCalendarName: nil,
            googleCalendarConnectionStatus: .disconnected,
            notificationPermissionStatus: .notDetermined,
            defaultSnoozeMinutes: 30,
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
        case googleCalendarAccountEmail
        case googleCalendarName
        case googleCalendarConnectionStatus
        case notificationPermissionStatus
        case defaultSnoozeMinutes
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
        googleCalendarAccountEmail: String?,
        googleCalendarName: String?,
        googleCalendarConnectionStatus: DLGoogleCalendarConnectionStatus,
        notificationPermissionStatus: DLNotificationPermissionStatus,
        defaultSnoozeMinutes: Int,
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
        self.googleCalendarAccountEmail = googleCalendarAccountEmail
        self.googleCalendarName = googleCalendarName
        self.googleCalendarConnectionStatus = googleCalendarConnectionStatus
        self.notificationPermissionStatus = notificationPermissionStatus
        self.defaultSnoozeMinutes = defaultSnoozeMinutes
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
        self.googleCalendarAccountEmail = try container.decodeIfPresent(String.self, forKey: .googleCalendarAccountEmail)
        self.googleCalendarName = try container.decodeIfPresent(String.self, forKey: .googleCalendarName)
        self.googleCalendarConnectionStatus = try container.decodeIfPresent(DLGoogleCalendarConnectionStatus.self, forKey: .googleCalendarConnectionStatus)
            ?? (self.googleCalendarID == nil ? .disconnected : .connected)
        if self.googleCalendarAccountEmail == "connected-google-account" {
            self.googleCalendarID = nil
            self.googleCalendarName = nil
            self.googleCalendarAccountEmail = nil
            self.googleCalendarConnectionStatus = .developmentPlaceholder
        }
        self.notificationPermissionStatus = try container.decodeIfPresent(DLNotificationPermissionStatus.self, forKey: .notificationPermissionStatus)
            ?? defaults.notificationPermissionStatus
        self.defaultSnoozeMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultSnoozeMinutes)
            ?? defaults.defaultSnoozeMinutes
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
