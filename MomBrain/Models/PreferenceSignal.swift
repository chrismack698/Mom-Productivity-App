import SwiftData
import Foundation

enum PreferenceSignalKind: String, Codable, CaseIterable {
    case completedTask
    case snoozedTask
    case editedTask
    case reminderIgnored
}

@Model
final class PreferenceSignal {
    var id: UUID
    var kind: PreferenceSignalKind
    var category: String
    var horizon: String
    var detail: String
    var createdAt: Date

    init(kind: PreferenceSignalKind, category: String, horizon: String, detail: String = "", createdAt: Date = Date()) {
        self.id = UUID()
        self.kind = kind
        self.category = category
        self.horizon = horizon
        self.detail = detail
        self.createdAt = createdAt
    }
}
