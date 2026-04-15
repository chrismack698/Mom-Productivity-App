import SwiftData
import Foundation

enum MessageRole: String, Codable {
    case user, assistant
}

@Model
final class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var actionItem: ActionItem?

    init(role: MessageRole, content: String, actionItem: ActionItem?) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.actionItem = actionItem
    }
}
