import Foundation

struct DLAIRequest {
    var input: String
    var sourceCaptureID: UUID?
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
        let itemType: DLParsedItemType
        if lowercased.contains("note") {
            itemType = .note
        } else if lowercased.contains("idea") {
            itemType = .idea
        } else if lowercased.contains("brain dump") || trimmed.count > 500 {
            itemType = .brainDump
        } else if lowercased.contains("remind me") {
            itemType = .reminder
        } else if lowercased.contains("block") || lowercased.contains("schedule") {
            itemType = .calendarBlock
        } else {
            itemType = .task
        }

        let calendarRequired = itemType == .calendarBlock
        let title = Self.makeTitle(from: trimmed)
        let needsClarification = itemType == .task && !Self.containsDateOrTime(lowercased)
        let warnings = needsClarification ? ["No clear date or time found. Keep this in Inbox until clarified."] : []

        return DLParserOutput(
            sourceCaptureID: request.sourceCaptureID,
            confidence: calendarRequired ? 0.62 : 0.72,
            items: [
                DLParsedItem(
                    type: itemType,
                    title: title,
                    summary: trimmed,
                    nextAction: itemType == .note || itemType == .brainDump ? nil : "Clarify the smallest next action.",
                    priority: lowercased.contains("urgent") ? .high : .normal,
                    calendarRequired: calendarRequired,
                    confidence: calendarRequired ? 0.62 : 0.72,
                    needsClarification: needsClarification,
                    warnings: warnings
                )
            ],
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

    private static func makeTitle(from input: String) -> String {
        let firstLine = input
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? input
        return String(firstLine.prefix(80))
    }

    private static func containsDateOrTime(_ input: String) -> Bool {
        ["today", "tomorrow", "tonight", "am", "pm", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].contains { input.contains($0) }
    }
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
