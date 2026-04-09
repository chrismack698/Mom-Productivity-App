// MyApp/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.claudeService) private var claudeService
    @Environment(\.notificationService) private var notificationService
    @State private var processor: TriageBatchProcessor?
    @State private var profileService: UserProfileService?

    var body: some View {
        FeedView(userProfileService: profileService)
            .onAppear { bootstrap() }
    }

    private func bootstrap() {
        guard processor == nil else { return }
        let container = modelContext.container
        let profile = UserProfileService(container: container, claudeService: claudeService)
        let batch = TriageBatchProcessor(
            container: container,
            claudeService: claudeService,
            notificationService: notificationService,
            userProfileService: profile
        )
        profileService = profile
        processor = batch
        Task { await batch.processPendingBatch() }
        batch.startPeriodicProcessing()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self], inMemory: true)
}
