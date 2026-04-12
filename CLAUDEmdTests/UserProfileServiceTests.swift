import Testing
import SwiftData
@testable import MyApp

struct UserProfileServiceTests {
    @Test func appendsObservationToLog() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, PreferenceSignal.self, UserPreference.self, MemorySummary.self, AppSettings.self,
            configurations: config
        )
        let service = UserProfileService(container: container, claudeService: StubClaudeService())
        await service.log("User completed: Reschedule pediatrician")
        await service.log("User snoozed: Return Nike shoes")

        let profile = await service.fetchOrCreateProfile()
        #expect(profile.observationLog.contains("completed"))
        #expect(profile.observationLog.contains("snoozed"))
    }

    @Test func doesNotSummarizeIfSummarizedToday() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, PreferenceSignal.self, UserPreference.self, MemorySummary.self, AppSettings.self,
            configurations: config
        )
        let spy = SpyClaudeServiceForProfile()
        let service = UserProfileService(container: container, claudeService: spy)

        // Pre-mark summarized today by logging and then setting the date
        let profile = await service.fetchOrCreateProfile()
        await MainActor.run {
            profile.lastSummarizedAt = Date()
            try? container.mainContext.save()
        }

        await service.summarizeIfNeeded()
        #expect(spy.chatCallCount == 0)
    }

    @Test func summarizesWhenObservationsExistAndNotSummarizedToday() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, PreferenceSignal.self, UserPreference.self, MemorySummary.self, AppSettings.self,
            configurations: config
        )
        let spy = SpyClaudeServiceForProfile()
        let service = UserProfileService(container: container, claudeService: spy)

        // Add observations so there's content to summarize
        await service.log("User completed: Reschedule pediatrician")
        await service.log("User completed: Return Nike shoes")

        // lastSummarizedAt is nil (never summarized) — should trigger summarization
        await service.summarizeIfNeeded()

        #expect(spy.chatCallCount == 0)

        // Verify summary was stored
        let profile = await service.fetchOrCreateProfile()
        #expect(!profile.preferenceSummary.isEmpty)
        #expect(profile.lastSummarizedAt != nil)
    }

    @Test func rateLimitReturnsFalseAfterTenCalls() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, PreferenceSignal.self, UserPreference.self, MemorySummary.self, AppSettings.self,
            configurations: config
        )
        let service = UserProfileService(container: container, claudeService: StubClaudeService())

        // Exhaust the free tier limit
        for _ in 0..<10 {
            await service.recordCloudCall()
        }

        let canCall = await service.canMakeCloudCall(isPaidUser: false)
        #expect(canCall == false)
    }

    @Test func rateLimitAllowsPaidUsers() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, PreferenceSignal.self, UserPreference.self, MemorySummary.self, AppSettings.self,
            configurations: config
        )
        let service = UserProfileService(container: container, claudeService: StubClaudeService())

        for _ in 0..<20 {
            await service.recordCloudCall()
        }

        let canCall = await service.canMakeCloudCall(isPaidUser: true)
        #expect(canCall == true)
    }
}

// MARK: - SpyClaudeService for this task's tests
final class SpyClaudeServiceForProfile: ClaudeService, @unchecked Sendable {
    var chatCallCount = 0

    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult] { [] }
    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String {
        chatCallCount += 1
        return "You tend to complete tasks in the morning. You often defer returns."
    }
}
