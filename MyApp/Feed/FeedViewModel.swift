import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class FeedViewModel {
    private let context: ModelContext
    var todayItems: [ActionItem] = []
    var thisWeekItems: [ActionItem] = []
    var somedayItems: [ActionItem] = []
    var pendingCaptureCount: Int = 0

    init(context: ModelContext) {
        self.context = context
    }

    func loadItems() {
        let descriptor = FetchDescriptor<ActionItem>(
            predicate: #Predicate { !$0.isComplete },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        todayItems = all.filter { $0.timeHorizon == .today }
        thisWeekItems = all.filter { $0.timeHorizon == .thisWeek }
        somedayItems = all.filter { $0.timeHorizon == .someday }

        let pendingDescriptor = FetchDescriptor<CaptureItem>(
            predicate: #Predicate { $0.processingStatus == ProcessingStatus.pending || $0.processingStatus == ProcessingStatus.processing }
        )
        pendingCaptureCount = (try? context.fetch(pendingDescriptor).count) ?? 0
    }

    func markComplete(_ item: ActionItem) {
        item.isComplete = true
        try? context.save()
    }

    func snooze(_ item: ActionItem) {
        switch item.timeHorizon {
        case .today: item.timeHorizon = .thisWeek
        case .thisWeek: item.timeHorizon = .someday
        case .someday: break
        }
        try? context.save()
    }
}
