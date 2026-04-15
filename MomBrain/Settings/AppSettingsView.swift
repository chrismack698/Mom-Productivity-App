import SwiftUI
import SwiftData

struct AppSettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var remindersEnabled = true
    @State private var preferredTodayCount = 3
    @State private var dailyDigestEnabled = false
    @State private var memorySummary = ""

    var body: some View {
        Form {
            Section("Today Feed") {
                Stepper(value: $preferredTodayCount, in: 1...5) {
                    Text("Keep Today to \(preferredTodayCount) item\(preferredTodayCount == 1 ? "" : "s")")
                }
                Text("A smaller Today list keeps the feed calming instead of backlog-heavy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Reminders") {
                Toggle("Enable reminders", isOn: $remindersEnabled)
                Toggle("Daily digest", isOn: $dailyDigestEnabled)
            }

            Section("Personalization") {
                if memorySummary.isEmpty {
                    Text("No learned preferences yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(memorySummary)
                }

                Button("Reset learned preferences", role: .destructive) {
                    resetPersonalization()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: remindersEnabled) { _, _ in save() }
        .onChange(of: preferredTodayCount) { _, _ in save() }
        .onChange(of: dailyDigestEnabled) { _, _ in save() }
    }

    private func load() {
        let settings = fetchSettings()
        remindersEnabled = settings.remindersEnabled
        preferredTodayCount = settings.preferredTodayCount
        dailyDigestEnabled = settings.dailyDigestEnabled
        memorySummary = ((try? context.fetch(FetchDescriptor<MemorySummary>()))?.first?.text) ?? ""
    }

    private func save() {
        let settings = fetchSettings()
        settings.remindersEnabled = remindersEnabled
        settings.preferredTodayCount = preferredTodayCount
        settings.dailyDigestEnabled = dailyDigestEnabled
        settings.updatedAt = Date()
        try? context.save()
    }

    private func resetPersonalization() {
        ((try? context.fetch(FetchDescriptor<PreferenceSignal>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<UserPreference>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<MemorySummary>())) ?? []).forEach { context.delete($0) }
        if let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first {
            profile.observationLog = ""
            profile.preferenceSummary = ""
            profile.lastSummarizedAt = nil
        }
        try? context.save()
        memorySummary = ""
    }

    private func fetchSettings() -> AppSettings {
        if let existing = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            return existing
        }

        let defaults = AppSettings()
        context.insert(defaults)
        try? context.save()
        return defaults
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
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
        ],
        inMemory: true
    )
}
