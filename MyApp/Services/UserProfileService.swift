import Foundation
import SwiftData

actor UserProfileService {
    private let container: ModelContainer
    private let claudeService: any ClaudeService

    init(container: ModelContainer, claudeService: any ClaudeService) {
        self.container = container
        self.claudeService = claudeService
    }

    // MARK: - Profile Access

    func fetchOrCreateProfile() async -> UserProfile {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }

    // MARK: - Observation Logging

    func log(_ observation: String) async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? context.fetch(descriptor))?.first ?? {
            let p = UserProfile(); context.insert(p); return p
        }() else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        profile.observationLog += "[\(timestamp)] \(observation)\n"
        try? context.save()
    }

    // MARK: - Daily Summarization

    func summarizeIfNeeded() async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? context.fetch(descriptor))?.first else { return }

        // Skip if already summarized today
        if let last = profile.lastSummarizedAt, Calendar.current.isDateInToday(last) { return }
        guard !profile.observationLog.isEmpty else { return }

        // Build a summarization prompt using the observation log
        let recentLog = String(profile.observationLog.suffix(5000))
        let prompt = """
        Based on these observations about a mom's productivity patterns, write a brief (3-5 sentence) preference summary.
        Focus on: when she tends to work, what she procrastinates, recurring constraints, categories that dominate.
        Keep it factual and concise — this will be injected into future AI prompts to personalize responses.

        Observations:
        \(recentLog)
        """

        do {
            // Use a synthetic task for the summarization call
            let dummyCapture = CaptureItem(rawContent: "profile summarization")
            let dummyTask = ActionItem(
                title: "Summarize",
                firstStep: "",
                timeHorizon: .someday,
                category: "admin",
                captureItem: dummyCapture
            )
            let summary = try await claudeService.chat(
                messages: [ChatMessage(role: .user, content: prompt, actionItem: dummyTask)],
                taskContext: dummyTask,
                userContext: ""
            )
            profile.preferenceSummary = summary
            profile.lastSummarizedAt = Date()
            try? context.save()
        } catch {
            // Silent — try again tomorrow
        }
    }

    // MARK: - Rate Limiting

    func canMakeCloudCall(isPaidUser: Bool) async -> Bool {
        if isPaidUser { return true }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? context.fetch(descriptor))?.first else { return true }

        // Reset daily count if it's a new day
        if !Calendar.current.isDateInToday(profile.dailyCallResetDate) {
            profile.dailyFreeCallsUsed = 0
            profile.dailyCallResetDate = Date()
            try? context.save()
        }

        return profile.dailyFreeCallsUsed < 10
    }

    func recordCloudCall() async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? context.fetch(descriptor))?.first else { return }
        profile.dailyFreeCallsUsed += 1
        try? context.save()
    }
}
