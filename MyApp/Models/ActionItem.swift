import SwiftData
import Foundation

enum TimeHorizon: String, Codable, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case someday = "Someday"
}

@Model
final class ActionItem {
    var id: UUID
    var title: String
    var firstStep: String
    var timeHorizon: TimeHorizon
    var deadline: Date?
    var category: String
    var isComplete: Bool
    var createdAt: Date
    var captureItem: CaptureItem?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.actionItem)
    var messages: [ChatMessage] = []

    init(title: String, firstStep: String, timeHorizon: TimeHorizon, category: String, captureItem: CaptureItem?, deadline: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.firstStep = firstStep
        self.timeHorizon = timeHorizon
        self.category = category
        self.captureItem = captureItem
        self.deadline = deadline
        self.isComplete = false
        self.createdAt = Date()
    }
}
