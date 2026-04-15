import SwiftData
import Foundation

@Model
final class UserPreference {
    var id: UUID
    var key: String
    var value: String
    var evidenceCount: Int
    var updatedAt: Date

    init(key: String, value: String, evidenceCount: Int, updatedAt: Date = Date()) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.evidenceCount = evidenceCount
        self.updatedAt = updatedAt
    }
}
