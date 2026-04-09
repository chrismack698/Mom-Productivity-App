import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    @AppStorage("claudeAPIKey") private var apiKey = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.claudeService, makeClaudeService())
                .environment(\.notificationService, StubNotificationService())
        }
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await triggerBatchProcessing()
                }
            }
        }
    }

    private func makeClaudeService() -> any ClaudeService {
        apiKey.isEmpty ? StubClaudeService() : ClaudeServiceImpl(apiKey: apiKey)
    }

    private func triggerBatchProcessing() async {
        // Note: TriageBatchProcessor requires a ModelContainer.
        // Full wiring happens in Task 10 when all services are assembled.
        // This placeholder ensures the hook is in place.
    }
}
