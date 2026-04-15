import SwiftData
import Foundation

@Model
final class MemorySummary {
    var id: UUID
    var text: String
    var updatedAt: Date

    init(text: String = "", updatedAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.updatedAt = updatedAt
    }
}
