// MomBrain/Detail/TaskDetailView.swift
import SwiftUI
import SwiftData

struct TaskDetailView: View {
    let item: ActionItem
    @Environment(\.modelContext) private var context
    @Environment(\.claudeService) private var claudeService
    @State private var viewModel: TaskDetailViewModel?

    var body: some View {
        VStack(spacing: 0) {
            // Task summary header
            VStack(alignment: .leading, spacing: 8) {
                Label(item.category.capitalized, systemImage: categoryIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("First step: \(item.firstStep)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial)

            Divider()

            // Chat thread
            let sortedMessages = item.messages.sorted(by: { $0.createdAt < $1.createdAt })
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if sortedMessages.isEmpty {
                            Text("Tap below to ask a follow-up question.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        ForEach(sortedMessages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if viewModel?.isSending == true {
                            HStack {
                                ProgressView()
                                    .padding(12)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: item.messages.count) { _, _ in
                    if let last = sortedMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 12) {
                TextField("Ask a follow-up…", text: Binding(
                    get: { viewModel?.inputText ?? "" },
                    set: { viewModel?.inputText = $0 }
                ), axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)

                Button {
                    guard let vm = viewModel else { return }
                    let text = vm.inputText
                    vm.inputText = ""
                    Task { await vm.send(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            viewModel?.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? AnyShapeStyle(Color.blue)
                            : AnyShapeStyle(Color.secondary)
                        )
                }
                .disabled(viewModel?.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }
            .padding()
            .background(.regularMaterial)
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel = TaskDetailViewModel(item: item, context: context, claudeService: claudeService)
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
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            Text(message.content)
                .padding(12)
                .background(
                    message.role == .user ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color(uiColor: .secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self, configurations: config)
    let capture = CaptureItem(rawContent: "preview")
    let item = ActionItem(title: "Get baby passport", firstStep: "Book post office appointment online", timeHorizon: .today, category: "admin", captureItem: capture)
    container.mainContext.insert(capture)
    container.mainContext.insert(item)
    return NavigationStack {
        TaskDetailView(item: item)
    }
    .modelContainer(container)
}
