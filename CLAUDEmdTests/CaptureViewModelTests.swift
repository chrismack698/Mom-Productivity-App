// CLAUDEmdTests/CaptureViewModelTests.swift
import Testing
import SwiftData
@testable import MyApp

@MainActor
struct CaptureViewModelTests {
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
    }

    @Test func textCaptureCreatesPendingItem() async throws {
        let vm = CaptureViewModel(context: container.mainContext)
        await vm.submitText("reschedule pediatrician appointment")
        let descriptor = FetchDescriptor<CaptureItem>()
        let items = try container.mainContext.fetch(descriptor)
        #expect(items.count == 1)
        #expect(items[0].rawContent == "reschedule pediatrician appointment")
        #expect(items[0].processingStatus == .pending)
    }

    @Test func emptyTextIsIgnored() async throws {
        let vm = CaptureViewModel(context: container.mainContext)
        await vm.submitText("   ")
        let descriptor = FetchDescriptor<CaptureItem>()
        let items = try container.mainContext.fetch(descriptor)
        #expect(items.isEmpty)
    }
}
