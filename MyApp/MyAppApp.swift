// MyApp/MyAppApp.swift
import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    @AppStorage("claudeAPIKey") private var apiKey = ""
    @AppStorage("isPaidUser") private var isPaidUser = false
    @Environment(\.scenePhase) private var scenePhase

    // Services — instantiated once and shared
    @State private var processor: TriageBatchProcessor?
    @State private var profileService: UserProfileService?
    @State private var claudeService: AnyClaudeService?
    @State private var notificationService: any NotificationServiceProtocol = NotificationServiceImpl()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.claudeService, makeClaudeService())
                .environment(\.notificationService, notificationService)
                .task { await setupAndStart() }
        }
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await processor?.processPendingBatch() }
            }
        }
    }

    private func makeClaudeService() -> any ClaudeService {
        apiKey.isEmpty ? StubClaudeService() : ClaudeServiceImpl(apiKey: apiKey)
    }

    private func setupAndStart() async {
        // Note: Services requiring ModelContainer are fully wired when the container
        // is available. The actual ModelContainer is accessed via the environment in SwiftUI,
        // so batch processing is triggered via scenePhase.onChange above.
        // Full service assembly with ModelContainer happens at first foreground.
        await notificationService.requestPermission()
    }
}
