import SwiftUI
import SwiftData

struct FeedView: View {
    var userProfileService: UserProfileService?
    @Environment(\.modelContext) private var context
    @State private var viewModel = FeedViewModel(context: ModelContext(try! ModelContainer(for: ActionItem.self)))
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    CaptureBarView(onCapture: { viewModel.loadItems() })
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
                    NavigationLink(destination: SettingsView()) {
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
            viewModel.userProfileService = userProfileService
            viewModel.loadItems()
        }
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
    FeedView(userProfileService: nil)
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self], inMemory: true)
}
