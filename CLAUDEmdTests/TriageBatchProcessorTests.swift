import Testing
import SwiftData
@testable import MyApp

struct TriageBatchProcessorTests {
    @Test func pendingItemsAreBatchedTogether() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
        await MainActor.run {
            let capture1 = CaptureItem(rawContent: "reschedule pediatrician")
            let capture2 = CaptureItem(rawContent: "return Nike shoes")
            container.mainContext.insert(capture1)
            container.mainContext.insert(capture2)
            try? container.mainContext.save()
        }

        let service = SpyClaudeService()
        let processor = TriageBatchProcessor(container: container, claudeService: service, notificationService: StubNotificationService())
        await processor.processPendingBatch()

        #expect(service.triageCallCount == 1)
        #expect(service.lastTriageBatchSize == 2)
    }

    @Test func alreadyProcessedItemsAreSkipped() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
        await MainActor.run {
            let done = CaptureItem(rawContent: "already done")
            done.processingStatus = .complete
            container.mainContext.insert(done)
            try? container.mainContext.save()
        }

        let service = SpyClaudeService()
        let processor = TriageBatchProcessor(container: container, claudeService: service, notificationService: StubNotificationService())
        await processor.processPendingBatch()

        #expect(service.triageCallCount == 0)
    }

    @Test func simpleShortCapturesHandledLocally() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
        await MainActor.run {
            // 3 words, no date language → simple capture
            let simple = CaptureItem(rawContent: "buy milk")
            container.mainContext.insert(simple)
            try? container.mainContext.save()
        }

        let service = SpyClaudeService()
        let processor = TriageBatchProcessor(container: container, claudeService: service, notificationService: StubNotificationService())
        await processor.processPendingBatch()

        // Simple captures should NOT trigger a cloud call
        #expect(service.triageCallCount == 0)

        // But an ActionItem should still be created
        let items: [ActionItem] = await MainActor.run {
            (try? container.mainContext.fetch(FetchDescriptor<ActionItem>())) ?? []
        }
        #expect(items.count == 1)
    }
}

// MARK: - Test Doubles
final class SpyClaudeService: ClaudeService, @unchecked Sendable {
    var triageCallCount = 0
    var lastTriageBatchSize = 0

    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult] {
        triageCallCount += 1
        lastTriageBatchSize = captures.count
        return []
    }

    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String {
        return "stub"
    }
}
