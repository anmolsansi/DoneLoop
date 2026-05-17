import Foundation

struct DLAIRequest {
    var input: String
    var sourceCaptureID: UUID?
    var timeZoneIdentifier: String = TimeZone.current.identifier
    var now: Date = Date()
}

enum DLAIProviderError: LocalizedError {
    case unavailable(String)
    case malformedResponse(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message), .malformedResponse(let message):
            message
        }
    }
}

protocol DLAIProviding {
    var name: String { get }
    var isAvailable: Bool { get }

    func parseCommand(_ request: DLAIRequest) async throws -> DLParserOutput
    func summarizeBrainDump(_ input: String) async throws -> String
    func breakDownTask(_ task: DLTask) async throws -> [DLParsedItem]
    func suggestTopThree(_ tasks: [DLTask]) async throws -> [UUID]
}

struct RuleBasedAIProvider: DLAIProviding {
    let name = "Rule-based"
    let isAvailable = true

    func parseCommand(_ request: DLAIRequest) async throws -> DLParserOutput {
        let trimmed = request.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DLAIProviderError.malformedResponse("Capture text is empty.")
        }

        let lowercased = trimmed.lowercased()
        let calendar = Self.calendar(timeZoneIdentifier: request.timeZoneIdentifier)
        let schedule = Self.parseSchedule(from: lowercased, now: request.now, calendar: calendar)
        let duration = Self.parseDuration(from: lowercased) ?? 30 * 60
        let title = Self.makeTitle(from: trimmed, lowercased: lowercased)
        let priority: DLTaskPriority = lowercased.contains("urgent") ? .high : .normal
        var items: [DLParsedItem] = []
        var warnings: [String] = []

        if Self.isNoteOnly(lowercased) {
            items.append(
                DLParsedItem(
                    type: .note,
                    title: title,
                    summary: trimmed,
                    priority: priority,
                    confidence: 0.78
                )
            )
        } else if lowercased.contains("idea") {
            items.append(
                DLParsedItem(
                    type: .idea,
                    title: title,
                    summary: trimmed,
                    nextAction: "Decide whether this should become a task.",
                    priority: priority,
                    confidence: 0.76
                )
            )
        } else if lowercased.contains("brain dump") || trimmed.count > 500 || trimmed.components(separatedBy: .newlines).count > 4 {
            warnings.append("Brain dump needs review before creating tasks.")
            items.append(
                DLParsedItem(
                    type: .brainDump,
                    title: title,
                    summary: trimmed,
                    priority: priority,
                    confidence: 0.64,
                    needsClarification: true,
                    warnings: warnings
                )
            )
        } else if lowercased.contains("remind me") {
            if schedule.start == nil {
                warnings.append("No clear reminder time found.")
            }
            items.append(
                DLParsedItem(
                    type: .reminder,
                    title: title,
                    summary: trimmed,
                    nextAction: "Handle the reminder when it fires.",
                    priority: priority,
                    dueDate: schedule.start,
                    dueTime: schedule.start,
                    confidence: schedule.start == nil ? 0.56 : 0.82,
                    needsClarification: schedule.start == nil,
                    warnings: warnings
                )
            )
        } else if lowercased.contains("block") || lowercased.contains("schedule this") || lowercased.contains("schedule ") {
            if lowercased.contains("every ") {
                warnings.append("Recurring schedules are not supported yet. This was parsed as a one-time item.")
            }

            if let start = schedule.start {
                let end = schedule.end ?? start.addingTimeInterval(duration)
                items.append(
                    DLParsedItem(
                        type: .task,
                        title: title,
                        summary: trimmed,
                        nextAction: "Start the scheduled work block.",
                        priority: priority,
                        scheduledStart: start,
                        scheduledEnd: end,
                        calendarRequired: false,
                        confidence: schedule.isAmbiguous ? 0.68 : 0.84,
                        needsClarification: schedule.isAmbiguous,
                        warnings: schedule.isAmbiguous ? ["Time is ambiguous. Review before saving."] : []
                    )
                )
                items.append(
                    DLParsedItem(
                        type: .calendarBlock,
                        title: title,
                        summary: "Calendar block for \(title).",
                        priority: priority,
                        scheduledStart: start,
                        scheduledEnd: end,
                        calendarRequired: true,
                        confidence: schedule.isAmbiguous ? 0.66 : 0.86,
                        needsClarification: schedule.isAmbiguous,
                        warnings: schedule.isAmbiguous ? ["Time is ambiguous. Review before saving."] : []
                    )
                )
            } else {
                warnings.append("No clear schedule found. This stays unscheduled until clarified.")
                items.append(
                    DLParsedItem(
                        type: .task,
                        title: title,
                        summary: trimmed,
                        nextAction: "Choose when to work on this.",
                        priority: priority,
                        confidence: 0.58,
                        needsClarification: true,
                        warnings: warnings
                    )
                )
            }
        } else {
            let needsClarification = schedule.start == nil
            if needsClarification {
                warnings.append("No clear date or time found. Keep this in Inbox until clarified.")
            }
            items.append(
                DLParsedItem(
                    type: .task,
                    title: title,
                    summary: trimmed,
                    nextAction: needsClarification ? "Choose when to work on this." : "Start the task.",
                    priority: priority,
                    dueDate: schedule.start,
                    dueTime: schedule.start,
                    confidence: needsClarification ? 0.62 : 0.78,
                    needsClarification: needsClarification,
                    warnings: warnings
                )
            )
        }

        return DLParserOutput(
            sourceCaptureID: request.sourceCaptureID,
            confidence: items.map(\.confidence).min() ?? 0.5,
            items: items,
            warnings: warnings
        )
    }

    func summarizeBrainDump(_ input: String) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DLAIProviderError.malformedResponse("Brain dump is empty.")
        }
        return String(trimmed.prefix(180))
    }

    func breakDownTask(_ task: DLTask) async throws -> [DLParsedItem] {
        [
            DLParsedItem(
                type: .task,
                title: "Start: \(task.title)",
                summary: task.summary,
                nextAction: task.nextAction ?? "Open the task and choose the first visible action.",
                priority: task.priority,
                confidence: 0.7
            )
        ]
    }

    func suggestTopThree(_ tasks: [DLTask]) async throws -> [UUID] {
        Array(
            tasks
                .filter { $0.status != .done && $0.status != .deleted }
                .sorted { lhs, rhs in
                    if lhs.priority != rhs.priority {
                        return lhs.priority.sortRank < rhs.priority.sortRank
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
                .prefix(3)
                .map(\.id)
        )
    }

    private static func makeTitle(from input: String, lowercased: String) -> String {
        if let blockTitle = firstMatch(in: input, pattern: #"(?i)\bblock\s+(?:one|\d+)?\s*(?:hour|hours|minute|minutes)?(?:\s+of)?\s*(?:time\s+)?to\s+(.+)$"#) {
            return cleanTitle(blockTitle)
        }

        if let reminderTitle = firstMatch(in: input, pattern: #"(?i)\bremind me(?:\s+tonight|\s+today|\s+tomorrow|\s+next\s+\w+)?(?:\s+at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?)?\s+to\s+(.+)$"#) {
            return cleanTitle(reminderTitle)
        }

        if lowercased.hasPrefix("i should ") {
            return cleanTitle(String(input.dropFirst("I should ".count)))
        }

        let firstLine = input
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? input
        return cleanTitle(firstLine)
    }

    private static func cleanTitle(_ input: String) -> String {
        var title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return String(title.prefix(80))
    }

    private static func isNoteOnly(_ input: String) -> Bool {
        input.hasPrefix("note ") || input.hasPrefix("note:") || input.contains("write this down")
    }

    private static func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar.current
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }
        return calendar
    }

    private static func parseSchedule(from input: String, now: Date, calendar: Calendar) -> ParsedSchedule {
        if let minutes = integerMatch(in: input, pattern: #"in\s+(\d+)\s+(?:minute|minutes|min|mins)"#) {
            return ParsedSchedule(start: now.addingTimeInterval(TimeInterval(minutes * 60)), end: nil, isAmbiguous: false)
        }

        var components = calendar.dateComponents([.year, .month, .day], from: baseDate(for: input, now: now, calendar: calendar))
        let time = parseTime(from: input)
        var isAmbiguous = false

        if let time {
            components.hour = time.hour
            components.minute = time.minute
            isAmbiguous = time.isAmbiguous
        } else if input.contains("tonight") {
            components.hour = 20
            components.minute = 0
        } else if input.contains("today") || input.contains("tomorrow") || input.contains("next ") || weekday(in: input) != nil {
            components.hour = 9
            components.minute = 0
            isAmbiguous = true
        } else {
            return ParsedSchedule(start: nil, end: nil, isAmbiguous: false)
        }

        guard var start = calendar.date(from: components) else {
            return ParsedSchedule(start: nil, end: nil, isAmbiguous: true)
        }

        if start < now {
            if input.contains("today") || !input.contains("tomorrow") {
                start = calendar.date(byAdding: .day, value: 1, to: start) ?? start
                isAmbiguous = true
            }
        }

        return ParsedSchedule(start: start, end: nil, isAmbiguous: isAmbiguous)
    }

    private static func baseDate(for input: String, now: Date, calendar: Calendar) -> Date {
        if input.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        }

        if let weekday = weekday(in: input) {
            return nextDate(matchingWeekday: weekday, after: now, calendar: calendar)
        }

        return now
    }

    private static func parseTime(from input: String) -> ParsedTime? {
        guard let rawHour = integerMatch(in: input, pattern: #"(?:\bat\s+|\btonight\s+at\s+)(\d{1,2})(?::\d{2})?\s*(?:am|pm)?"#) else {
            return nil
        }

        let minute = integerMatch(in: input, pattern: #"(?:\bat\s+|\btonight\s+at\s+)\d{1,2}:(\d{2})"#) ?? 0
        let hasAM = input.contains("am")
        let hasPM = input.contains("pm")
        var hour = rawHour
        var isAmbiguous = !hasAM && !hasPM

        if hasPM && hour < 12 {
            hour += 12
        } else if hasAM && hour == 12 {
            hour = 0
        } else if input.contains("tonight") && !hasAM && !hasPM && hour < 12 {
            hour += 12
            isAmbiguous = false
        }

        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return ParsedTime(hour: hour, minute: minute, isAmbiguous: isAmbiguous)
    }

    private static func parseDuration(from input: String) -> TimeInterval? {
        if input.contains("one hour") || input.contains("an hour") {
            return 3600
        }

        if let hours = integerMatch(in: input, pattern: #"(\d+)\s+(?:hour|hours)"#) {
            return TimeInterval(hours * 3600)
        }

        if let minutes = integerMatch(in: input, pattern: #"(\d+)\s+(?:minute|minutes|min|mins)"#) {
            return TimeInterval(minutes * 60)
        }

        return nil
    }

    private static func weekday(in input: String) -> Int? {
        let weekdays = [
            "sunday": 1,
            "monday": 2,
            "tuesday": 3,
            "wednesday": 4,
            "thursday": 5,
            "friday": 6,
            "saturday": 7
        ]
        return weekdays.first { input.contains($0.key) }?.value
    }

    private static func nextDate(matchingWeekday weekday: Int, after date: Date, calendar: Calendar) -> Date {
        let todayWeekday = calendar.component(.weekday, from: date)
        let daysAhead = (weekday - todayWeekday + 7) % 7
        let normalizedDaysAhead = daysAhead == 0 ? 7 : daysAhead
        return calendar.date(byAdding: .day, value: normalizedDaysAhead, to: date) ?? date
    }

    private static func firstMatch(in input: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, range: range), match.numberOfRanges > 1 else { return nil }
        guard let matchRange = Range(match.range(at: 1), in: input) else { return nil }
        return String(input[matchRange])
    }

    private static func integerMatch(in input: String, pattern: String) -> Int? {
        firstMatch(in: input, pattern: pattern).flatMap { Int($0) }
    }
}

private struct ParsedSchedule {
    var start: Date?
    var end: Date?
    var isAmbiguous: Bool
}

private struct ParsedTime {
    var hour: Int
    var minute: Int
    var isAmbiguous: Bool
}

struct UnavailableAIProvider: DLAIProviding {
    let name: String
    let message: String
    let isAvailable = false

    func parseCommand(_ request: DLAIRequest) async throws -> DLParserOutput {
        throw DLAIProviderError.unavailable(message)
    }

    func summarizeBrainDump(_ input: String) async throws -> String {
        throw DLAIProviderError.unavailable(message)
    }

    func breakDownTask(_ task: DLTask) async throws -> [DLParsedItem] {
        throw DLAIProviderError.unavailable(message)
    }

    func suggestTopThree(_ tasks: [DLTask]) async throws -> [UUID] {
        throw DLAIProviderError.unavailable(message)
    }
}

@MainActor
final class AIProviderRouter: ObservableObject {
    private let ruleBased = RuleBasedAIProvider()
    private let localPlaceholder = UnavailableAIProvider(
        name: "Local model",
        message: "Local model integration is not installed yet. Rule-based parsing is available."
    )
    private let cloudPlaceholder = UnavailableAIProvider(
        name: "Cloud fallback",
        message: "Cloud fallback is not configured. Rule-based parsing is available."
    )

    func provider(for settings: DLUserSettings) -> DLAIProviding {
        switch settings.aiMode {
        case .localOnly:
            return ruleBased
        case .localWithFallback:
            return ruleBased
        case .bringYourOwnKey:
            return ruleBased
        }
    }

    func modeDetail(for settings: DLUserSettings) -> String {
        switch settings.aiMode {
        case .localOnly:
            "Local only, using rule-based parser until on-device model integration lands"
        case .localWithFallback:
            "Local first, cloud fallback placeholder is disabled until configured"
        case .bringYourOwnKey:
            "Bring Your Own Key is planned, using rule-based parser for now"
        }
    }

    func parseCommand(_ request: DLAIRequest, settings: DLUserSettings) async -> Result<DLParserOutput, Error> {
        let selectedProvider = provider(for: settings)

        do {
            let output = try await selectedProvider.parseCommand(request)
            guard output.isValid else {
                throw DLAIProviderError.malformedResponse(output.validationErrors().joined(separator: " "))
            }
            return .success(output)
        } catch {
            return .failure(error)
        }
    }
}

private extension DLTaskPriority {
    var sortRank: Int {
        switch self {
        case .high: 0
        case .normal: 1
        case .low: 2
        }
    }
}
