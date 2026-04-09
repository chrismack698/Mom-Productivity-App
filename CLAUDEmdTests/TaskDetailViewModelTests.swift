// CLAUDEmdTests/TaskDetailViewModelTests.swift
import Testing
import SwiftData
@testable import MyApp

@MainActor
struct TaskDetailViewModelTests {
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
    }

    private func makeActionItem() -> ActionItem {
        let capture = CaptureItem(rawContent: "reschedule pediatrician")
        let item = ActionItem(title: "Reschedule pediatrician", firstStep: "Call office", timeHorizon: .today, category: "appointment", captureItem: capture)
        container.mainContext.insert(capture)
        container.mainContext.insert(item)
        return item
    }

    @Test func addUserMessageAppendsToThread() async throws {
        let item = makeActionItem()
        let vm = TaskDetailViewModel(item: item, context: container.mainContext, claudeService: StubClaudeService())
        await vm.send("Can you break this into smaller steps?")
        #expect(item.messages.count >= 1)
        #expect(item.messages.first?.role == .user)
    }

    @Test func sendingEmptyMessageDoesNothing() async throws {
        let item = makeActionItem()
        let vm = TaskDetailViewModel(item: item, context: container.mainContext, claudeService: StubClaudeService())
        await vm.send("   ")
        #expect(item.messages.isEmpty)
    }
}
