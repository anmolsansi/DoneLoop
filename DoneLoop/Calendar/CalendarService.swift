import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum DLCalendarServiceError: Error, Equatable {
    case disconnected
    case realSyncUnavailable
    case missingSchedule
    case invalidSchedule
    case missingEvent
    case missingOAuthConfiguration
    case oauthFailed
    case tokenMissing
    case networkFailed
}

struct DLCalendarEventDraft: Equatable {
    var title: String
    var start: Date
    var end: Date
    var timeZoneIdentifier: String
    var notes: String
}

@MainActor
final class CalendarService: NSObject, ObservableObject {
    @Published private(set) var isConnecting = false
    @Published private(set) var lastConnectionMessage: String?

    private let keychain: KeychainStore
    private let calendarTokenKey = "google-calendar-token"
    private var authSession: ASWebAuthenticationSession?

    init(keychain: KeychainStore = .shared) {
        self.keychain = keychain
        super.init()
    }

    var connectionLabel: String {
        "Google Calendar"
    }

    var realSyncUnavailableMessage: String {
        "Google OAuth is not configured. Scheduled work stays local and no Google event is created."
    }

    func connect(store: LocalStore) {
        guard let clientID = store.settings.googleOAuthClientID?.nonEmpty,
              let redirectScheme = store.settings.googleOAuthRedirectScheme?.nonEmpty
        else {
            store.updateSettings { settings in
                settings.googleCalendarConnectionStatus = .developmentPlaceholder
            }
            lastConnectionMessage = "Enter a Google OAuth client ID and redirect scheme before connecting."
            syncScheduledTasks(in: store)
            return
        }

        isConnecting = true
        lastConnectionMessage = nil

        Task {
            do {
                let token = try await runOAuth(clientID: clientID, redirectScheme: redirectScheme)
                try saveToken(token)
                store.updateSettings { settings in
                    settings.googleCalendarConnectionStatus = .connected
                    settings.googleCalendarID = "primary"
                    settings.googleCalendarName = "Primary Calendar"
                    settings.googleCalendarAccountEmail = "Connected Google account"
                }
                lastConnectionMessage = "Google Calendar connected."
                syncScheduledTasks(in: store)
            } catch {
                store.updateSettings { settings in
                    settings.googleCalendarConnectionStatus = .permissionDenied
                }
                lastConnectionMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }

    func saveOAuthConfiguration(clientID: String, redirectScheme: String, store: LocalStore) {
        store.updateSettings { settings in
            settings.googleOAuthClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            settings.googleOAuthRedirectScheme = redirectScheme.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }
    }

    func disconnect(store: LocalStore) {
        keychain.delete(account: calendarTokenKey)
        store.updateSettings { settings in
            settings.googleCalendarConnectionStatus = .disconnected
            settings.googleCalendarID = nil
            settings.googleCalendarName = nil
            settings.googleCalendarAccountEmail = nil
        }
        store.markSyncedCalendarTasksDisconnected()
    }

    func simulatePermissionDenied(store: LocalStore) {
        store.updateSettings { settings in
            settings.googleCalendarConnectionStatus = .permissionDenied
            settings.googleCalendarID = nil
            settings.googleCalendarName = nil
            settings.googleCalendarAccountEmail = nil
        }
    }

    func syncScheduledTasks(in store: LocalStore) {
        for task in store.tasks where shouldCreateCalendarEvent(for: task) {
            _ = createEvent(for: task.id, in: store)
        }
    }

    @discardableResult
    func createEvent(for taskID: UUID, in store: LocalStore) -> Result<String, DLCalendarServiceError> {
        guard hasOAuthConfiguration(settings: store.settings) else {
            store.markTaskCalendarDisconnected(id: taskID, message: realSyncUnavailableMessage)
            return .failure(.missingOAuthConfiguration)
        }

        guard isConnected(settings: store.settings) else {
            store.markTaskCalendarDisconnected(id: taskID, message: "Connect real Google Calendar sync before creating external events.")
            return .failure(.disconnected)
        }

        guard let task = store.task(id: taskID), shouldCreateCalendarEvent(for: task) else {
            store.markTaskCalendarSyncNotScheduled(id: taskID)
            return .failure(.missingSchedule)
        }

        guard let draft = makeDraft(for: task, settings: store.settings) else {
            store.markTaskCalendarSyncFailed(id: taskID, message: "Scheduled work needs a start and end time.")
            return .failure(.invalidSchedule)
        }

        Task {
            do {
                let eventID = try await upsertRemoteEvent(task: task, draft: draft, settings: store.settings)
                store.markTaskCalendarSynced(id: taskID, eventID: eventID)
            } catch {
                store.markTaskCalendarSyncFailed(id: taskID, message: error.localizedDescription)
            }
        }

        return .success(task.calendarEventID ?? "pending-google-calendar-event-\(task.id.uuidString.lowercased())")
    }

    @discardableResult
    func updateEvent(for taskID: UUID, in store: LocalStore) -> Result<String, DLCalendarServiceError> {
        guard let task = store.task(id: taskID), task.calendarEventID != nil else {
            return createEvent(for: taskID, in: store)
        }
        return createEvent(for: taskID, in: store)
    }

    @discardableResult
    func deleteEvent(for taskID: UUID, in store: LocalStore) -> Result<Void, DLCalendarServiceError> {
        guard hasOAuthConfiguration(settings: store.settings) else {
            store.disconnectTaskCalendarEvent(id: taskID)
            return .failure(.missingOAuthConfiguration)
        }

        guard isConnected(settings: store.settings) else {
            store.markTaskCalendarDisconnected(id: taskID, message: "Connect real Google Calendar sync before deleting external events.")
            return .failure(.disconnected)
        }
        guard let task = store.task(id: taskID), task.calendarEventID != nil else {
            return .failure(.missingEvent)
        }

        Task {
            do {
                try await deleteRemoteEvent(task: task, settings: store.settings)
            } catch {
                store.markTaskCalendarSyncFailed(id: taskID, message: error.localizedDescription)
            }
        }
        store.disconnectTaskCalendarEvent(id: taskID)
        return .success(())
    }

    func shouldCreateCalendarEvent(for task: DLTask) -> Bool {
        task.status != .deleted
            && task.status != .done
            && task.scheduledStart != nil
            && task.scheduledEnd != nil
    }

    func makeDraft(for task: DLTask, settings: DLUserSettings) -> DLCalendarEventDraft? {
        guard let start = task.scheduledStart, let end = task.scheduledEnd, end > start else { return nil }
        return DLCalendarEventDraft(
            title: task.title,
            start: start,
            end: end,
            timeZoneIdentifier: settings.timezoneIdentifier,
            notes: task.nextAction ?? task.summary ?? "Created by DoneLoop."
        )
    }

    func isConnected(settings: DLUserSettings) -> Bool {
        return settings.googleCalendarConnectionStatus == .connected
            && settings.googleCalendarID != nil
            && (try? loadToken()) != nil
    }

    private func hasOAuthConfiguration(settings: DLUserSettings) -> Bool {
        settings.googleOAuthClientID?.nonEmpty != nil && settings.googleOAuthRedirectScheme?.nonEmpty != nil
    }

    private func runOAuth(clientID: String, redirectScheme: String) async throws -> DLSecureToken {
        let verifier = Self.randomURLSafeString(byteCount: 48)
        let challenge = Self.codeChallenge(for: verifier)
        let redirectURI = "\(redirectScheme):/oauth2redirect"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/calendar.events"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components?.url else { throw DLCalendarServiceError.missingOAuthConfiguration }

        let callbackURL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: redirectScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? DLCalendarServiceError.oauthFailed)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            if !session.start() {
                continuation.resume(throwing: DLCalendarServiceError.oauthFailed)
            }
        }

        let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
        guard let code else { throw DLCalendarServiceError.oauthFailed }

        return try await exchangeCodeForToken(code: code, verifier: verifier, clientID: clientID, redirectURI: redirectURI)
    }

    private func exchangeCodeForToken(code: String, verifier: String, clientID: String, redirectURI: String) async throws -> DLSecureToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        request.httpBody = Self.formURLEncoded(body).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DLCalendarServiceError.oauthFailed }
        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        return DLSecureToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: tokenResponse.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) },
            scope: tokenResponse.scope
        )
    }

    private func upsertRemoteEvent(task: DLTask, draft: DLCalendarEventDraft, settings: DLUserSettings) async throws -> String {
        guard let calendarID = settings.googleCalendarID else { throw DLCalendarServiceError.disconnected }
        var token = try loadUsableToken(settings: settings)
        let eventID = task.calendarEventID
        let urlString: String
        let method: String
        if let eventID {
            urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarID.urlPathEncoded)/events/\(eventID.urlPathEncoded)"
            method = "PUT"
        } else {
            urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarID.urlPathEncoded)/events"
            method = "POST"
        }
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = method
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GoogleCalendarEventRequest(draft: draft))

        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401, token.refreshToken != nil {
            token = try await refreshToken(token, settings: settings)
            request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
            let retry = try await URLSession.shared.data(for: request)
            guard (retry.1 as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw DLCalendarServiceError.networkFailed }
            return try JSONDecoder().decode(GoogleCalendarEventResponse.self, from: retry.0).id
        }

        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw DLCalendarServiceError.networkFailed }
        return try JSONDecoder().decode(GoogleCalendarEventResponse.self, from: data).id
    }

    private func deleteRemoteEvent(task: DLTask, settings: DLUserSettings) async throws {
        guard let calendarID = settings.googleCalendarID, let eventID = task.calendarEventID else { throw DLCalendarServiceError.missingEvent }
        let token = try loadUsableToken(settings: settings)
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarID.urlPathEncoded)/events/\(eventID.urlPathEncoded)"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw DLCalendarServiceError.networkFailed }
    }

    private func loadUsableToken(settings: DLUserSettings) throws -> DLSecureToken {
        guard let token = try loadToken() else { throw DLCalendarServiceError.tokenMissing }
        if let expiresAt = token.expiresAt, expiresAt < Date().addingTimeInterval(60), token.refreshToken != nil {
            return token
        }
        return token
    }

    private func refreshToken(_ token: DLSecureToken, settings: DLUserSettings) async throws -> DLSecureToken {
        guard let refreshToken = token.refreshToken, let clientID = settings.googleOAuthClientID else { throw DLCalendarServiceError.tokenMissing }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncoded([
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DLCalendarServiceError.tokenMissing }
        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        let newToken = DLSecureToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAt: tokenResponse.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) },
            scope: tokenResponse.scope ?? token.scope
        )
        try saveToken(newToken)
        return newToken
    }

    private func saveToken(_ token: DLSecureToken) throws {
        let data = try JSONEncoder().encode(token)
        try keychain.save(data, account: calendarTokenKey)
    }

    private func loadToken() throws -> DLSecureToken? {
        guard let data = try keychain.load(account: calendarTokenKey) else { return nil }
        return try JSONDecoder().decode(DLSecureToken.self, from: data)
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func formURLEncoded(_ values: [String: String]) -> String {
        values
            .map { "\($0.key.urlQueryEncoded)=\($0.value.urlQueryEncoded)" }
            .joined(separator: "&")
    }
}

extension CalendarService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        DispatchQueue.main.sync {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

private struct GoogleTokenResponse: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresIn: Int?
    var scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
    }
}

private struct GoogleCalendarEventRequest: Encodable {
    struct DateTime: Encodable {
        var dateTime: String
        var timeZone: String
    }

    var summary: String
    var description: String
    var start: DateTime
    var end: DateTime

    init(draft: DLCalendarEventDraft) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        summary = draft.title
        description = draft.notes
        start = DateTime(dateTime: formatter.string(from: draft.start), timeZone: draft.timeZoneIdentifier)
        end = DateTime(dateTime: formatter.string(from: draft.end), timeZone: draft.timeZoneIdentifier)
    }
}

private struct GoogleCalendarEventResponse: Decodable {
    var id: String
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var urlQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }

    var urlPathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
