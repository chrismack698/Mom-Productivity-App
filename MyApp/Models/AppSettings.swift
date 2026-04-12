import SwiftData
import Foundation

@Model
final class AppSettings {
    var id: UUID
    var remindersEnabled: Bool
    var preferredTodayCount: Int
    var dailyDigestEnabled: Bool
    var updatedAt: Date

    init(remindersEnabled: Bool = true, preferredTodayCount: Int = 3, dailyDigestEnabled: Bool = false, updatedAt: Date = Date()) {
        self.id = UUID()
        self.remindersEnabled = remindersEnabled
        self.preferredTodayCount = preferredTodayCount
        self.dailyDigestEnabled = dailyDigestEnabled
        self.updatedAt = updatedAt
    }
}
