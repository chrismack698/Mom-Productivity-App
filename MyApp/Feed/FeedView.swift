import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = FeedViewModel(context: ModelContext(try! ModelContainer(for: ActionItem.self)))
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    // Capture bar placeholder — replaced when CaptureBarView is added in Task 5
                    captureBarPlaceholder
                        .padding(.horizontal)
                        .padding(.top)

                    if viewModel.pendingCaptureCount > 0 {
                        Label("\(viewModel.pendingCaptureCount) item\(viewModel.pendingCaptureCount == 1 ? "" : "s") processing…", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }

                    feedSection("Today", items: viewModel.todayItems)
                    feedSection("This Week", items: viewModel.thisWeekItems)
                    feedSection("Someday", items: viewModel.somedayItems)

                    if viewModel.todayItems.isEmpty && viewModel.thisWeekItems.isEmpty && viewModel.somedayItems.isEmpty {
                        ContentUnavailableView(
                            "Nothing on your plate",
                            systemImage: "checkmark.circle",
                            description: Text("Capture something to get started.")
                        )
                        .padding(.top, 60)
                    }
                }
            }
            .navigationTitle("Second Brain")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: Text("Settings coming in Task 10")) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: ActionItem.self) { item in
                TaskDetailView(item: item)
            }
        }
        .onAppear {
            viewModel = FeedViewModel(context: context)
            viewModel.loadItems()
        }
    }

    private var captureBarPlaceholder: some View {
        HStack {
            Image(systemName: "mic")
                .foregroundStyle(.secondary)
            Text("Add anything…")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "camera")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: Capsule())
    }

    @ViewBuilder
    private func feedSection(_ title: String, items: [ActionItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 20)
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        ActionItemCardView(
                            item: item,
                            onComplete: { viewModel.markComplete(item) },
                            onSnooze: { viewModel.snooze(item) }
                        )
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    FeedView()
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self], inMemory: true)
}
