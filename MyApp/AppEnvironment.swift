import SwiftUI

// MARK: - Claude Service Protocol
protocol ClaudeService: Sendable {
    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult]
    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String
}

// MARK: - Notification Service Protocol
protocol NotificationServiceProtocol: Sendable {
    func schedule(title: String, body: String, at date: Date) async throws
    func requestPermission() async -> Bool
}

// MARK: - Environment Keys
private struct ClaudeServiceKey: EnvironmentKey {
    static let defaultValue: any ClaudeService = StubClaudeService()
}

private struct NotificationServiceKey: EnvironmentKey {
    static let defaultValue: any NotificationServiceProtocol = StubNotificationService()
}

extension EnvironmentValues {
    var claudeService: any ClaudeService {
        get { self[ClaudeServiceKey.self] }
        set { self[ClaudeServiceKey.self] = newValue }
    }

    var notificationService: any NotificationServiceProtocol {
        get { self[NotificationServiceKey.self] }
        set { self[NotificationServiceKey.self] = newValue }
    }
}

// MARK: - Stubs (replaced in Tasks 6 and 9)
struct StubClaudeService: ClaudeService {
    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult] { [] }
    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String { "" }
}

struct StubNotificationService: NotificationServiceProtocol {
    func schedule(title: String, body: String, at date: Date) async throws {}
    func requestPermission() async -> Bool { true }
}

// MARK: - TriageResult (shared type used in Tasks 6 and 7)
struct TriageResult: Decodable, Sendable {
    let title: String
    let firstStep: String
    let timeHorizon: TimeHorizon
    let deadline: Date?
    let category: String
    let scheduledNotification: ScheduledNotification?

    struct ScheduledNotification: Decodable, Sendable {
        let title: String
        let body: String
        let triggerDate: Date
    }
}
