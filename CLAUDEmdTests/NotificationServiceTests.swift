import Testing
@testable import MyApp
import UserNotifications

struct NotificationServiceTests {
    @Test func scheduleCreatesRequestWithCorrectContent() async throws {
        let center = MockNotificationCenter()
        let service = NotificationServiceImpl(center: center)
        let triggerDate = Date().addingTimeInterval(3600) // 1 hour from now
        try await service.schedule(title: "Return Nike shoes", body: "Drop off at UPS", at: triggerDate)
        #expect(center.addedRequests.count == 1)
        #expect(center.addedRequests[0].content.title == "Return Nike shoes")
        #expect(center.addedRequests[0].content.body == "Drop off at UPS")
    }

    @Test func schedulePastDateIsIgnored() async throws {
        let center = MockNotificationCenter()
        let service = NotificationServiceImpl(center: center)
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        try await service.schedule(title: "Ignored", body: "Should not fire", at: pastDate)
        #expect(center.addedRequests.isEmpty)
    }

    @Test func requestPermissionReturnsFromCenter() async throws {
        let center = MockNotificationCenter()
        center.authorizationResult = true
        let service = NotificationServiceImpl(center: center)
        let result = await service.requestPermission()
        #expect(result == true)
    }
}

// MARK: - Mock
final class MockNotificationCenter: UNUserNotificationCenterProtocol, @unchecked Sendable {
    var addedRequests: [UNNotificationRequest] = []
    var authorizationResult = false

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationResult
    }
}
