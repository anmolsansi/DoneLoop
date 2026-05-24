import Foundation

enum DLValidationSeverity: String, Equatable {
    case blocking
    case needsClarification
    case warning
}

struct DLValidationIssue: Error, Identifiable, Equatable {
    let id = UUID()
    let severity: DLValidationSeverity
    let message: String
}

struct DLParserValidationResult: Equatable {
    var issues: [DLValidationIssue]

    var blockingIssues: [DLValidationIssue] {
        issues.filter { $0.severity == .blocking }
    }

    var clarificationIssues: [DLValidationIssue] {
        issues.filter { $0.severity == .needsClarification }
    }

    var warningIssues: [DLValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    var canSave: Bool {
        blockingIssues.isEmpty
    }

    var needsClarification: Bool {
        !clarificationIssues.isEmpty
    }
}

enum DLParserOutputValidator {
    static func validate(
        _ output: DLParserOutput,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DLParserValidationResult {
        var issues: [DLValidationIssue] = output.validationErrors().map {
            DLValidationIssue(severity: .blocking, message: $0)
        }

        if output.intent != .createItems {
            issues.append(
                DLValidationIssue(
                    severity: .blocking,
                    message: "This command changes an existing task, but no target task is selected yet."
                )
            )
        }

        for item in output.items {
            issues.append(contentsOf: validate(item, now: now, calendar: calendar))
        }

        for warning in output.warnings where !warning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(DLValidationIssue(severity: .warning, message: warning))
        }

        return DLParserValidationResult(issues: issues.deduplicatedByMessage())
    }

    static func decodeAndValidate(
        json: String,
        decoder: JSONDecoder = JSONDecoder()
    ) -> Result<(DLParserOutput, DLParserValidationResult), DLValidationIssue> {
        do {
            decoder.dateDecodingStrategy = .iso8601
            guard let data = json.data(using: .utf8) else {
                return .failure(
                    DLValidationIssue(
                        severity: .blocking,
                        message: "Parser output is not readable text."
                    )
                )
            }
            let output = try decoder.decode(DLParserOutput.self, from: data)
            return .success((output, validate(output)))
        } catch {
            return .failure(
                DLValidationIssue(
                    severity: .blocking,
                    message: "Parser output is not valid JSON."
                )
            )
        }
    }

    private static func validate(
        _ item: DLParsedItem,
        now: Date,
        calendar: Calendar
    ) -> [DLValidationIssue] {
        var issues: [DLValidationIssue] = []
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.count > 120 {
            issues.append(
                DLValidationIssue(
                    severity: .blocking,
                    message: "\"\(title.prefix(40))\" has a title that is too long."
                )
            )
        }

        if let summary = item.summary, summary.count > 2_000 {
            issues.append(
                DLValidationIssue(
                    severity: .blocking,
                    message: "\"\(safeTitle(item))\" has a summary that is too long."
                )
            )
        }

        if let nextAction = item.nextAction, nextAction.count > 300 {
            issues.append(
                DLValidationIssue(
                    severity: .blocking,
                    message: "\"\(safeTitle(item))\" has a next action that is too long."
                )
            )
        }

        if item.needsClarification {
            issues.append(
                DLValidationIssue(
                    severity: item.calendarRequired ? .blocking : .needsClarification,
                    message: "\"\(safeTitle(item))\" needs a decision before it can be scheduled."
                )
            )
        }

        if item.calendarRequired {
            if item.scheduledStart == nil || item.scheduledEnd == nil {
                issues.append(
                    DLValidationIssue(
                        severity: .blocking,
                        message: "\"\(safeTitle(item))\" asks for Calendar but does not have a specific start and end time."
                    )
                )
            }
        }

        if let scheduledStart = item.scheduledStart, scheduledStart < now.addingTimeInterval(-60) {
            let severity: DLValidationSeverity = item.calendarRequired ? .blocking : .needsClarification
            issues.append(
                DLValidationIssue(
                    severity: severity,
                    message: "\"\(safeTitle(item))\" is scheduled in the past."
                )
            )
        }

        if let dueDate = item.dueDate, dueDate < calendar.startOfDay(for: now) {
            issues.append(
                DLValidationIssue(
                    severity: .needsClarification,
                    message: "\"\(safeTitle(item))\" has a due date in the past."
                )
            )
        }

        for warning in item.warnings where !warning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                DLValidationIssue(
                    severity: .warning,
                    message: "\"\(safeTitle(item))\": \(warning)"
                )
            )
        }

        return issues
    }

    private static func safeTitle(_ item: DLParsedItem) -> String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled item" : title
    }
}

private extension Array where Element == DLValidationIssue {
    func deduplicatedByMessage() -> [DLValidationIssue] {
        var seen: Set<String> = []
        return filter { issue in
            let key = "\(issue.severity.rawValue):\(issue.message)"
            return seen.insert(key).inserted
        }
    }
}
