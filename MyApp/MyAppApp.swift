// MyApp/MyAppApp.swift
import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // Services — instantiated once and shared
    @State private var processor: TriageBatchProcessor?
    @State private var notificationService: any NotificationServiceProtocol = NotificationServiceImpl()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.claudeService, makeClaudeService())
                .environment(\.notificationService, notificationService)
                .task { await setupAndStart() }
        }
        .modelContainer(
            for: [
                CaptureItem.self,
                ActionItem.self,
                ChatMessage.self,
                UserProfile.self,
                PreferenceSignal.self,
                UserPreference.self,
                MemorySummary.self,
                AppSettings.self
            ]
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await processor?.processPendingBatch() }
            }
        }
    }

    private func makeClaudeService() -> any ClaudeService {
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        return apiKey.isEmpty ? StubClaudeService() : ClaudeServiceImpl(apiKey: apiKey)
    }

    private func setupAndStart() async {
        await notificationService.requestPermission()
    }
}
