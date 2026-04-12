import Testing
import SwiftData
@testable import MyApp

@MainActor
struct ModelTests {
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, PreferenceSignal.self, UserPreference.self, MemorySummary.self, AppSettings.self,
            configurations: config
        )
    }

    @Test func captureItemDefaultsToProcessingPending() throws {
        let item = CaptureItem(rawContent: "reschedule pediatrician")
        container.mainContext.insert(item)
        #expect(item.processingStatus == .pending)
        #expect(item.imageReference == nil)
    }

    @Test func actionItemLinkedToCaptureItem() throws {
        let capture = CaptureItem(rawContent: "test")
        let action = ActionItem(
            title: "Call doctor",
            firstStep: "Find the number",
            timeHorizon: .today,
            category: "appointment",
            captureItem: capture
        )
        container.mainContext.insert(capture)
        container.mainContext.insert(action)
        #expect(action.captureItem != nil)
        #expect(action.isComplete == false)
        #expect(action.deadline == nil)
    }

    @Test func chatMessageLinkedToActionItem() throws {
        let capture = CaptureItem(rawContent: "test")
        let action = ActionItem(
            title: "Test",
            firstStep: "Step",
            timeHorizon: .thisWeek,
            category: "errand",
            captureItem: capture
        )
        let message = ChatMessage(role: .user, content: "Can you break this down more?", actionItem: action)
        container.mainContext.insert(capture)
        container.mainContext.insert(action)
        container.mainContext.insert(message)
        #expect(message.role == .user)
        #expect(action.messages.count == 1)
    }

    @Test func userProfileDefaultsToEmptyStrings() throws {
        let profile = UserProfile()
        container.mainContext.insert(profile)
        #expect(profile.observationLog == "")
        #expect(profile.preferenceSummary == "")
    }
}
