import SwiftUI
import SwiftData

struct ActionItemEditorView: View {
    let item: ActionItem
    let viewModel: FeedViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var titleText = ""
    @State private var firstStepText = ""

    var body: some View {
        Form {
            Section {
                Text("If AI got this wrong, edit it directly. Keep it concrete and boring.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Task") {
                TextField("Title", text: $titleText)
                TextField("First step", text: $firstStepText, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Timing") {
                LabeledContent("Bucket", value: item.timeHorizon.rawValue)
                if let deadline = item.deadline {
                    LabeledContent("Deadline") {
                        Text(deadline, style: .date)
                    }
                }
                LabeledContent("Category", value: item.category.capitalized)
            }

            Section("Actions") {
                Button("Save Changes") {
                    viewModel.saveEdits(for: item, title: titleText, firstStep: firstStepText)
                }
                Button(snoozeLabel) {
                    viewModel.snooze(item)
                    syncFromItem()
                }
                Button("Mark Done", role: .destructive) {
                    viewModel.markComplete(item)
                    dismiss()
                }
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncFromItem)
    }

    private var snoozeLabel: String {
        switch item.timeHorizon {
        case .today: "Move to This Week"
        case .thisWeek: "Move to Later"
        case .someday: "Keep in Later"
        }
    }

    private func syncFromItem() {
        titleText = item.title
        firstStepText = item.firstStep
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: CaptureItem.self,
        ActionItem.self,
        ChatMessage.self,
        UserProfile.self,
        PreferenceSignal.self,
        UserPreference.self,
        MemorySummary.self,
        AppSettings.self,
        configurations: config
    )
    let feedVM = FeedViewModel(context: container.mainContext)
    let capture = CaptureItem(rawContent: "preview")
    let item = ActionItem(
        title: "Reschedule pediatrician appointment",
        firstStep: "Call the office to ask about next week",
        timeHorizon: .today,
        category: "appointment",
        captureItem: capture
    )
    container.mainContext.insert(capture)
    container.mainContext.insert(item)

    return NavigationStack {
        ActionItemEditorView(item: item, viewModel: feedVM)
    }
    .modelContainer(container)
}
