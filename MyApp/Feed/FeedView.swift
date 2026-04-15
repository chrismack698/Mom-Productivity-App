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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Say it once. It won't slip.")
                            .font(.subheadline.weight(.semibold))
                        Text("Capture a thought fast, then let the app turn it into the next right action.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 12)

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
                            description: Text("Capture a life-admin thought to get started.")
                        )
                        .padding(.top, 60)
                    }
                }
            }
            .navigationTitle("Family Admin")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AppSettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: ActionItem.self) { item in
                ActionItemEditorView(item: item, viewModel: viewModel)
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
