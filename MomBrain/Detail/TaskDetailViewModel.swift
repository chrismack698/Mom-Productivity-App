// MomBrain/Detail/TaskDetailViewModel.swift
import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class TaskDetailViewModel {
    let item: ActionItem
    private let context: ModelContext
    private let claudeService: any ClaudeService
    var isSending = false
    var inputText = ""

    init(item: ActionItem, context: ModelContext, claudeService: any ClaudeService) {
        self.item = item
        self.context = context
        self.claudeService = claudeService
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed, actionItem: item)
        context.insert(userMessage)
        item.messages.append(userMessage)
        try? context.save()

        isSending = true
        defer { isSending = false }

        do {
            let reply = try await claudeService.chat(
                messages: item.messages,
                taskContext: item,
                userContext: ""
            )
            guard !reply.isEmpty else { return }
            let assistantMessage = ChatMessage(role: .assistant, content: reply, actionItem: item)
            context.insert(assistantMessage)
            item.messages.append(assistantMessage)
            try? context.save()
        } catch {
            // Silent failure — user message stays, they can retry
        }
    }
}
