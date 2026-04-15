import UserNotifications

// MARK: - Protocol (testability)
protocol UNUserNotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}
extension UNUserNotificationCenter: UNUserNotificationCenterProtocol {}

// MARK: - Implementation
final class NotificationServiceImpl: NotificationServiceProtocol, Sendable {
    private let center: any UNUserNotificationCenterProtocol

    init(center: any UNUserNotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func schedule(title: String, body: String, at date: Date) async throws {
        guard date > Date() else { return } // Don't schedule past notifications

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }
}
