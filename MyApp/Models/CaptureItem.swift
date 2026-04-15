import SwiftData
import Foundation

enum ProcessingStatus: String, Codable {
    case pending, processing, complete, failed
}

@Model
final class CaptureItem {
    var id: UUID
    var rawContent: String
    var imageReference: String?
    var capturedAt: Date
    var processingStatus: ProcessingStatus

    @Relationship(deleteRule: .cascade, inverse: \ActionItem.captureItem)
    var actionItems: [ActionItem] = []

    init(rawContent: String, imageReference: String? = nil) {
        self.id = UUID()
        self.rawContent = rawContent
        self.imageReference = imageReference
        self.capturedAt = Date()
        self.processingStatus = .pending
    }
}
