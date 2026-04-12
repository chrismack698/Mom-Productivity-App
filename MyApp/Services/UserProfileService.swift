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
        let updatedLog = profile.observationLog + "[\(timestamp)] \(observation)\n"
        profile.observationLog = boundedLog(updatedLog)
        recordSignal(from: observation, context: context)
        refreshDerivedPreferences(context: context)
        rebuildSummary(context: context, profile: profile)
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
        refreshDerivedPreferences(context: context)
        rebuildSummary(context: context, profile: profile)
        try? context.save()
        return

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

    func resetPersonalization() async {
        let context = ModelContext(container)

        ((try? context.fetch(FetchDescriptor<PreferenceSignal>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<UserPreference>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<MemorySummary>())) ?? []).forEach { context.delete($0) }

        if let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first {
            profile.observationLog = ""
            profile.preferenceSummary = ""
            profile.lastSummarizedAt = nil
        }

        try? context.save()
    }

    // MARK: - Private

    private func boundedLog(_ value: String) -> String {
        let lines = value
            .split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(50)
            .map(String.init)
        return lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
    }

    private func recordSignal(from observation: String, context: ModelContext) {
        let lower = observation.lowercased()
        let kind: PreferenceSignalKind
        if lower.contains("snoozed") {
            kind = .snoozedTask
        } else if lower.contains("edited") {
            kind = .editedTask
        } else if lower.contains("ignored reminder") {
            kind = .reminderIgnored
        } else {
            kind = .completedTask
        }

        let category = extractValue(from: observation, label: "category") ?? "general"
        let horizon = extractValue(from: observation, label: "horizon") ?? "unknown"
        context.insert(PreferenceSignal(kind: kind, category: category, horizon: horizon, detail: observation))
    }

    private func extractValue(from observation: String, label: String) -> String? {
        guard let range = observation.range(of: "\(label): ") else { return nil }
        let suffix = observation[range.upperBound...]
        let stopIndex = suffix.firstIndex(of: "]") ?? suffix.endIndex
        let value = suffix[..<stopIndex]
        return value.isEmpty ? nil : String(value)
    }

    private func refreshDerivedPreferences(context: ModelContext) {
        let signals = (try? context.fetch(FetchDescriptor<PreferenceSignal>())) ?? []
        guard !signals.isEmpty else { return }

        let snoozes = signals.filter { $0.kind == .snoozedTask }
        let completions = signals.filter { $0.kind == .completedTask }

        upsertPreference(
            key: "today_feed_size",
            value: snoozes.count >= 3 ? "3" : "5",
            evidenceCount: max(snoozes.count, 1),
            context: context
        )

        let deferredCategories = Dictionary(grouping: snoozes, by: \.category)
            .filter { $0.value.count >= 2 && $0.key != "general" }
        if let topDeferred = deferredCategories.max(by: { $0.value.count < $1.value.count }) {
            upsertPreference(
                key: "frequently_deferred_category",
                value: topDeferred.key,
                evidenceCount: topDeferred.value.count,
                context: context
            )
        }

        let completedCategories = Dictionary(grouping: completions, by: \.category)
            .filter { $0.value.count >= 1 && $0.key != "general" }
        if let topCompleted = completedCategories.max(by: { $0.value.count < $1.value.count }) {
            upsertPreference(
                key: "frequently_completed_category",
                value: topCompleted.key,
                evidenceCount: topCompleted.value.count,
                context: context
            )
        }
    }

    private func upsertPreference(key: String, value: String, evidenceCount: Int, context: ModelContext) {
        let descriptor = FetchDescriptor<UserPreference>(
            predicate: #Predicate { $0.key == key }
        )

        if let existing = (try? context.fetch(descriptor))?.first {
            existing.value = value
            existing.evidenceCount = evidenceCount
            existing.updatedAt = Date()
        } else {
            context.insert(UserPreference(key: key, value: value, evidenceCount: evidenceCount))
        }
    }

    private func rebuildSummary(context: ModelContext, profile: UserProfile) {
        let preferences = ((try? context.fetch(FetchDescriptor<UserPreference>())) ?? [])
            .sorted(by: { $0.updatedAt > $1.updatedAt })

        let todaySize = preferences.first(where: { $0.key == "today_feed_size" })?.value ?? "3"
        let deferred = preferences.first(where: { $0.key == "frequently_deferred_category" })?.value
        let completed = preferences.first(where: { $0.key == "frequently_completed_category" })?.value

        var parts = ["Prefers a small Today list of about \(todaySize) items."]
        if let deferred {
            parts.append("Often defers \(deferred) tasks unless they are time-sensitive.")
        }
        if let completed {
            parts.append("Tends to complete \(completed) tasks promptly once they are clarified.")
        }

        let summaryText = parts.joined(separator: " ")
        profile.preferenceSummary = summaryText
        profile.lastSummarizedAt = Date()

        let descriptor = FetchDescriptor<MemorySummary>()
        if let summary = (try? context.fetch(descriptor))?.first {
            summary.text = summaryText
            summary.updatedAt = Date()
        } else {
            context.insert(MemorySummary(text: summaryText))
        }
    }
}
