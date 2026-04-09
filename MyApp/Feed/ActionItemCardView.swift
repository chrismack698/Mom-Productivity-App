import SwiftUI

struct ActionItemCardView: View {
    let item: ActionItem
    let onComplete: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(item.category.capitalized, systemImage: categoryIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let deadline = item.deadline {
                    Text(deadline, style: .date)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                }
            }
            Text(item.title)
                .font(.body)
                .fontWeight(.medium)
            Text("First step: \(item.firstStep)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onComplete) {
                Label("Done", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .leading) {
            Button(action: onSnooze) {
                Label("Snooze", systemImage: "clock.arrow.circlepath")
            }
            .tint(.orange)
        }
    }

    private var categoryIcon: String {
        switch item.category {
        case "appointment": return "calendar"
        case "errand": return "bag"
        case "admin": return "doc.text"
        case "personal": return "heart"
        default: return "circle"
        }
    }

    private var isOverdue: Bool {
        guard let deadline = item.deadline else { return false }
        return deadline < Date()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, configurations: config)
    let capture = CaptureItem(rawContent: "preview")
    let item = ActionItem(
        title: "Reschedule pediatrician appointment",
        firstStep: "Call Dr. Smith's office to check availability",
        timeHorizon: .today,
        category: "appointment",
        captureItem: capture
    )
    ActionItemCardView(item: item, onComplete: {}, onSnooze: {})
        .padding()
        .modelContainer(container)
}
