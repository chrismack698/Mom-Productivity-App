import SwiftData
import Foundation

@Model
final class UserProfile {
    var id: UUID
    var observationLog: String
    var preferenceSummary: String
    var lastSummarizedAt: Date?
    var dailyFreeCallsUsed: Int
    var dailyCallResetDate: Date

    init() {
        self.id = UUID()
        self.observationLog = ""
        self.preferenceSummary = ""
        self.lastSummarizedAt = nil
        self.dailyFreeCallsUsed = 0
        self.dailyCallResetDate = Date()
    }
}
