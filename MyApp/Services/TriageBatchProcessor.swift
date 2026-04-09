import Foundation
import SwiftData

actor TriageBatchProcessor {
    private let container: ModelContainer
    private let claudeService: any ClaudeService
    private let notificationService: any NotificationServiceProtocol
    private let userProfileService: UserProfileService

    init(container: ModelContainer, claudeService: any ClaudeService, notificationService: any NotificationServiceProtocol, userProfileService: UserProfileService) {
        self.container = container
        self.claudeService = claudeService
        self.notificationService = notificationService
        self.userProfileService = userProfileService
    }

    func processPendingBatch() async {
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<CaptureItem>(
            predicate: #Predicate { $0.processingStatus == ProcessingStatus.pending }
        )
        let pending = (try? context.fetch(descriptor)) ?? []
        guard !pending.isEmpty else { return }

        // Split: simple captures handled locally, complex ones go to cloud
        let (simple, complex) = pending.reduce(into: ([CaptureItem](), [CaptureItem]())) { acc, item in
            if isSimple(item.rawContent) {
                acc.0.append(item)
            } else {
                acc.1.append(item)
            }
        }

        // Handle simple captures locally (no cloud call)
        for capture in simple {
            handleLocally(capture, context: context)
        }

        // Handle complex captures via Claude
        if !complex.isEmpty {
            complex.forEach { $0.processingStatus = .processing }
            try? context.save()

            // Fetch user context
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let userContext = (try? context.fetch(profileDescriptor))?.first?.preferenceSummary ?? ""

            // Check rate limit before calling cloud
            guard await userProfileService.canMakeCloudCall(isPaidUser: false) else {
                // Rate limited — reset complex captures to pending so they retry tomorrow
                complex.forEach { $0.processingStatus = .pending }
                try? context.save()
                return
            }
            await userProfileService.recordCloudCall()

            do {
                let results = try await claudeService.triage(captures: complex, userContext: userContext)

                for result in results {
                    let action = ActionItem(
                        title: result.title,
                        firstStep: result.firstStep,
                        timeHorizon: result.timeHorizon,
                        category: result.category,
                        captureItem: complex.first,
                        deadline: result.deadline
                    )
                    context.insert(action)

                    // Schedule notification if AI returned one
                    if let notification = result.scheduledNotification {
                        try? await notificationService.schedule(
                            title: notification.title,
                            body: notification.body,
                            at: notification.triggerDate
                        )
                    }
                }

                complex.forEach { $0.processingStatus = .complete }

            } catch {
                // Retry on next foreground — reset to pending
                complex.forEach { $0.processingStatus = .pending }
            }

            try? context.save()
        }
    }

    /// Starts a background timer that processes pending captures every 3 minutes.
    func startPeriodicProcessing() {
        Task {
            while !Task.isCancelled {
                await processPendingBatch()
                try? await Task.sleep(for: .seconds(180))
            }
        }
    }

    // MARK: - Private

    private func isSimple(_ content: String) -> Bool {
        let words = content.split(separator: " ")
        guard words.count <= 8 else { return false }
        let dateTriggers = ["today", "tomorrow", "week", "month", "deadline", "by", "due", "before", "after", "when", "reschedule", "schedule", "appointment", "return"]
        let lower = content.lowercased()
        return !dateTriggers.contains(where: { lower.contains($0) })
    }

    private func handleLocally(_ capture: CaptureItem, context: ModelContext) {
        let action = ActionItem(
            title: capture.rawContent.capitalized,
            firstStep: "Take care of: \(capture.rawContent)",
            timeHorizon: .someday,
            category: "errand",
            captureItem: capture,
            deadline: nil
        )
        context.insert(action)
        capture.processingStatus = .complete
    }
}
