import Testing
import SwiftData
@testable import MyApp

@MainActor
struct FeedViewModelTests {
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, PreferenceSignal.self, UserPreference.self, MemorySummary.self, AppSettings.self,
            configurations: config
        )
    }

    private func makeItem(horizon: TimeHorizon, complete: Bool = false) -> ActionItem {
        let capture = CaptureItem(rawContent: "test")
        container.mainContext.insert(capture)
        let item = ActionItem(
            title: "Test",
            firstStep: "Do it",
            timeHorizon: horizon,
            category: "errand",
            captureItem: capture
        )
        item.isComplete = complete
        container.mainContext.insert(item)
        return item
    }

    @Test func groupsByTimeHorizon() throws {
        let vm = FeedViewModel(context: container.mainContext)
        _ = makeItem(horizon: .today)
        _ = makeItem(horizon: .today)
        _ = makeItem(horizon: .thisWeek)
        _ = makeItem(horizon: .someday)
        vm.loadItems()
        #expect(vm.todayItems.count == 2)
        #expect(vm.thisWeekItems.count == 1)
        #expect(vm.somedayItems.count == 1)
    }

    @Test func completedItemsExcludedFromFeed() throws {
        let vm = FeedViewModel(context: container.mainContext)
        _ = makeItem(horizon: .today, complete: true)
        _ = makeItem(horizon: .today, complete: false)
        vm.loadItems()
        #expect(vm.todayItems.count == 1)
    }

    @Test func markCompleteRemovesFromFeed() throws {
        let vm = FeedViewModel(context: container.mainContext)
        let item = makeItem(horizon: .today)
        vm.loadItems()
        #expect(vm.todayItems.count == 1)
        vm.markComplete(item)
        vm.loadItems()
        #expect(vm.todayItems.count == 0)
    }

    @Test func snoozeMovesItemToNextHorizon() throws {
        let vm = FeedViewModel(context: container.mainContext)
        let item = makeItem(horizon: .today)
        vm.loadItems()
        vm.snooze(item)
        #expect(item.timeHorizon == .thisWeek)
    }
}
