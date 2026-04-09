import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.claudeService, StubClaudeService())
                .environment(\.notificationService, StubNotificationService())
        }
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self])
    }
}
