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
    var userProfileService: UserProfileService?

    init(context: ModelContext) {
        self.context = context
    }

    func loadItems() {
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first ?? {
            let defaults = AppSettings()
            context.insert(defaults)
            try? context.save()
            return defaults
        }()

        let descriptor = FetchDescriptor<ActionItem>(
            predicate: #Predicate { !$0.isComplete },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        todayItems = Array(all.filter { $0.timeHorizon == .today }.prefix(settings.preferredTodayCount))
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
        Task {
            await userProfileService?.log("User completed: \(item.title) [category: \(item.category), horizon: \(item.timeHorizon.rawValue)]")
        }
    }

    func snooze(_ item: ActionItem) {
        let from = item.timeHorizon
        switch item.timeHorizon {
        case .today: item.timeHorizon = .thisWeek
        case .thisWeek: item.timeHorizon = .someday
        case .someday: break
        }
        try? context.save()
        Task {
            await userProfileService?.log("User snoozed: \(item.title) [category: \(item.category), horizon: \(from.rawValue)]")
        }
    }

    func saveEdits(for item: ActionItem, title: String, firstStep: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFirstStep = firstStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedFirstStep.isEmpty else { return }

        let changed = item.title != trimmedTitle || item.firstStep != trimmedFirstStep
        item.title = trimmedTitle
        item.firstStep = trimmedFirstStep
        try? context.save()

        if changed {
            Task {
                await userProfileService?.log("User edited: \(item.title) [category: \(item.category), horizon: \(item.timeHorizon.rawValue)]")
            }
        }
    }
}
