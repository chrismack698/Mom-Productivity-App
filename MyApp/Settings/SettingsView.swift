// MyApp/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("claudeAPIKey") private var apiKey = ""
    @AppStorage("isPaidUser") private var isPaidUser = false
    @State private var notificationsEnabled = false
    @Environment(\.notificationService) private var notificationService

    var body: some View {
        Form {
            Section("AI") {
                SecureField("Claude API Key", text: $apiKey)
                    .textContentType(.password)
                Text("Get your API key at console.anthropic.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Enable Reminders", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            Task {
                                let granted = await notificationService.requestPermission()
                                if !granted { notificationsEnabled = false }
                            }
                        }
                    }
            }

            Section("Account") {
                if isPaidUser {
                    Label("Unlimited plan active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    LabeledContent("Plan", value: "Free · 10 AI captures/day")
                    // StoreKit purchase is out of scope for v1 — placeholder text only
                    Text("Upgrade coming soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent(
                    "Version",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                )
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
