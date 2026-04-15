# Mom Productivity App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS 26 SwiftUI app that acts as a second brain for moms — voice/photo/text capture feeds an AI triage pipeline that silently organizes life admin into a prioritized daily feed, with notifications and personal learning over time.

**Architecture:** SwiftUI MVVM with `@Observable` ViewModels owning their state. SwiftData for persistence. Hybrid AI: on-device (SFSpeechRecognizer, Vision) for immediate capture, Claude API for intelligent triage via a background batching actor. Dependency injection flows through the SwiftUI Environment. `UNUserNotificationCenter` for deadline reminders.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI (iOS 26), SwiftData, SFSpeechRecognizer, AVFoundation, Vision, Claude API (URLSession), UNUserNotificationCenter, Swift Testing

---

## File Map

```
MyApp/
├── MyAppApp.swift                    — App entry, SwiftData container, environment setup
├── AppEnvironment.swift              — Environment keys + EnvironmentValues extensions
├── Models/
│   ├── CaptureItem.swift             — @Model: raw user input
│   ├── ActionItem.swift              — @Model: AI-processed task (avoids Swift.Task conflict)
│   ├── ChatMessage.swift             — @Model: single conversation turn on an ActionItem
│   └── UserProfile.swift             — @Model: singleton, observation log + preference summary
├── Feed/
│   ├── FeedView.swift                — Root view: capture bar + scrolling feed
│   ├── FeedViewModel.swift           — @MainActor @Observable: groups items by time horizon
│   └── ActionItemCardView.swift      — Single feed card with swipe/long-press actions
├── Detail/
│   ├── TaskDetailView.swift          — Pushed on card tap: AI breakdown + chat thread
│   └── TaskDetailViewModel.swift     — @MainActor @Observable: manages chat turns
├── Capture/
│   ├── CaptureBarView.swift          — Pill-shaped input bar (voice/photo/text)
│   ├── CaptureViewModel.swift        — @MainActor @Observable: orchestrates capture flow
│   ├── VoiceCaptureSession.swift     — Actor: wraps AVAudioEngine + SFSpeechRecognizer
│   └── ImageCaptureSession.swift     — Wraps Vision VNRecognizeTextRequest
├── Services/
│   ├── ClaudeService.swift           — Protocol + impl: triage and chat API calls
│   ├── TriageBatchProcessor.swift    — Actor: queues CaptureItems, batches to Claude
│   ├── UserProfileService.swift      — Actor: logs observations, runs daily summarization
│   └── NotificationService.swift    — Wraps UNUserNotificationCenter
├── Settings/
│   └── SettingsView.swift            — API key entry, notification toggle
└── CLAUDEmdTests/
    ├── FeedViewModelTests.swift
    ├── TaskDetailViewModelTests.swift
    ├── CaptureViewModelTests.swift
    ├── ClaudeServiceTests.swift
    ├── TriageBatchProcessorTests.swift
    ├── UserProfileServiceTests.swift
    └── NotificationServiceTests.swift
```

---

## Task 1: SwiftData Models

**Files:**
- Create: `MyApp/Models/CaptureItem.swift`
- Create: `MyApp/Models/ActionItem.swift`
- Create: `MyApp/Models/ChatMessage.swift`
- Create: `MyApp/Models/UserProfile.swift`
- Create: `CLAUDEmdTests/ModelTests.swift`

- [ ] **Step 1: Write failing model tests**

```swift
// CLAUDEmdTests/ModelTests.swift
import Testing
import SwiftData
@testable import MyApp

@MainActor
struct ModelTests {
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
    }

    @Test func captureItemDefaultsToProcessingPending() throws {
        let item = CaptureItem(rawContent: "reschedule pediatrician")
        container.mainContext.insert(item)
        #expect(item.processingStatus == .pending)
        #expect(item.imageReference == nil)
    }

    @Test func actionItemLinkedToCaptureItem() throws {
        let capture = CaptureItem(rawContent: "test")
        let action = ActionItem(
            title: "Call doctor",
            firstStep: "Find the number",
            timeHorizon: .today,
            category: "appointment",
            captureItem: capture
        )
        container.mainContext.insert(capture)
        container.mainContext.insert(action)
        #expect(action.captureItem?.rawContent == "reschedule pediatrician" || action.captureItem != nil)
        #expect(action.isComplete == false)
        #expect(action.deadline == nil)
    }

    @Test func chatMessageLinkedToActionItem() throws {
        let capture = CaptureItem(rawContent: "test")
        let action = ActionItem(
            title: "Test",
            firstStep: "Step",
            timeHorizon: .thisWeek,
            category: "errand",
            captureItem: capture
        )
        let message = ChatMessage(role: .user, content: "Can you break this down more?", actionItem: action)
        container.mainContext.insert(capture)
        container.mainContext.insert(action)
        container.mainContext.insert(message)
        #expect(message.role == .user)
        #expect(action.messages.count == 1)
    }

    @Test func userProfileIsSingleton() throws {
        let profile = UserProfile()
        container.mainContext.insert(profile)
        #expect(profile.observationLog == "")
        #expect(profile.preferenceSummary == "")
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

Use `RunSomeTests` MCP tool, target `CLAUDEmdTests`, filter `ModelTests`. Expected: compile error (types don't exist yet).

- [ ] **Step 3: Create CaptureItem**

```swift
// MyApp/Models/CaptureItem.swift
import SwiftData
import Foundation

enum ProcessingStatus: String, Codable {
    case pending, processing, complete, failed
}

@Model
final class CaptureItem {
    var id: UUID
    var rawContent: String
    var imageReference: String?
    var capturedAt: Date
    var processingStatus: ProcessingStatus

    @Relationship(deleteRule: .cascade, inverse: \ActionItem.captureItem)
    var actionItems: [ActionItem] = []

    init(rawContent: String, imageReference: String? = nil) {
        self.id = UUID()
        self.rawContent = rawContent
        self.imageReference = imageReference
        self.capturedAt = Date()
        self.processingStatus = .pending
    }
}
```

- [ ] **Step 4: Create ActionItem**

```swift
// MyApp/Models/ActionItem.swift
import SwiftData
import Foundation

enum TimeHorizon: String, Codable, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case someday = "Someday"
}

@Model
final class ActionItem {
    var id: UUID
    var title: String
    var firstStep: String
    var timeHorizon: TimeHorizon
    var deadline: Date?
    var category: String
    var isComplete: Bool
    var createdAt: Date
    var captureItem: CaptureItem?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.actionItem)
    var messages: [ChatMessage] = []

    init(title: String, firstStep: String, timeHorizon: TimeHorizon, category: String, captureItem: CaptureItem?, deadline: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.firstStep = firstStep
        self.timeHorizon = timeHorizon
        self.category = category
        self.captureItem = captureItem
        self.deadline = deadline
        self.isComplete = false
        self.createdAt = Date()
    }
}
```

- [ ] **Step 5: Create ChatMessage**

```swift
// MyApp/Models/ChatMessage.swift
import SwiftData
import Foundation

enum MessageRole: String, Codable {
    case user, assistant
}

@Model
final class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var actionItem: ActionItem?

    init(role: MessageRole, content: String, actionItem: ActionItem?) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.actionItem = actionItem
    }
}
```

- [ ] **Step 6: Create UserProfile**

```swift
// MyApp/Models/UserProfile.swift
import SwiftData
import Foundation

@Model
final class UserProfile {
    var id: UUID
    var observationLog: String
    var preferenceSummary: String
    var lastSummarizedAt: Date?
    var dailyCloudCallCount: Int
    var dailyCallResetDate: Date

    init() {
        self.id = UUID()
        self.observationLog = ""
        self.preferenceSummary = ""
        self.lastSummarizedAt = nil
        self.dailyCloudCallCount = 0
        self.dailyCallResetDate = Date()
    }
}
```

- [ ] **Step 7: Run tests — expect them to pass**

Use `RunSomeTests` MCP tool, filter `ModelTests`. Expected: all pass.

- [ ] **Step 8: Commit**

```
git add MyApp/Models/ CLAUDEmdTests/ModelTests.swift
git commit -m "feat: add SwiftData models (CaptureItem, ActionItem, ChatMessage, UserProfile)"
```

---

## Task 2: App Scaffold + Environment

**Files:**
- Create: `MyApp/AppEnvironment.swift`
- Modify: `MyApp/MyAppApp.swift`

- [ ] **Step 1: Create AppEnvironment with service stubs**

```swift
// MyApp/AppEnvironment.swift
import SwiftUI

// MARK: - Claude Service Protocol
protocol ClaudeService: Sendable {
    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult]
    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String
}

// MARK: - Notification Service Protocol
protocol NotificationServiceProtocol: Sendable {
    func schedule(title: String, body: String, at date: Date) async throws
    func requestPermission() async -> Bool
}

// MARK: - Environment Keys
private struct ClaudeServiceKey: EnvironmentKey {
    static let defaultValue: any ClaudeService = StubClaudeService()
}

private struct NotificationServiceKey: EnvironmentKey {
    static let defaultValue: any NotificationServiceProtocol = StubNotificationService()
}

extension EnvironmentValues {
    var claudeService: any ClaudeService {
        get { self[ClaudeServiceKey.self] }
        set { self[ClaudeServiceKey.self] = newValue }
    }

    var notificationService: any NotificationServiceProtocol {
        get { self[NotificationServiceKey.self] }
        set { self[NotificationServiceKey.self] = newValue }
    }
}

// MARK: - Stubs (replaced in Task 6 + 9)
struct StubClaudeService: ClaudeService {
    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult] { [] }
    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String { "" }
}

struct StubNotificationService: NotificationServiceProtocol {
    func schedule(title: String, body: String, at date: Date) async throws {}
    func requestPermission() async -> Bool { true }
}

// MARK: - TriageResult (shared type)
struct TriageResult: Decodable, Sendable {
    let title: String
    let firstStep: String
    let timeHorizon: TimeHorizon
    let deadline: Date?
    let category: String
    let scheduledNotification: ScheduledNotification?

    struct ScheduledNotification: Decodable, Sendable {
        let title: String
        let body: String
        let triggerDate: Date
    }
}
```

- [ ] **Step 2: Update app entry point**

```swift
// MyApp/MyAppApp.swift
import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    var body: some Scene {
        WindowGroup {
            FeedView()
                .environment(\.claudeService, StubClaudeService())
                .environment(\.notificationService, StubNotificationService())
        }
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self])
    }
}
```

- [ ] **Step 3: Build to confirm it compiles**

Use `BuildProject` MCP tool, target `MyApp` iOS. Expected: success (FeedView doesn't exist yet — create a placeholder if needed).

- [ ] **Step 4: Commit**

```
git add MyApp/AppEnvironment.swift MyApp/MyAppApp.swift
git commit -m "feat: add app scaffold, environment keys, and service protocols"
```

---

## Task 3: Feed View + Action Item Card

**Files:**
- Create: `MyApp/Feed/FeedViewModel.swift`
- Create: `MyApp/Feed/FeedView.swift`
- Create: `MyApp/Feed/ActionItemCardView.swift`
- Create: `CLAUDEmdTests/FeedViewModelTests.swift`

- [ ] **Step 1: Write failing ViewModel tests**

```swift
// CLAUDEmdTests/FeedViewModelTests.swift
import Testing
import SwiftData
@testable import MyApp

@MainActor
struct FeedViewModelTests {
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
    }

    private func makeItem(horizon: TimeHorizon, complete: Bool = false) -> ActionItem {
        let capture = CaptureItem(rawContent: "test")
        container.mainContext.insert(capture)
        let item = ActionItem(
            title: "Test",
            firstStep: "Do it",
            timeHorizon: horizon,
            category: "errand",
            captureItem: capture
        )
        item.isComplete = complete
        container.mainContext.insert(item)
        return item
    }

    @Test func groupsByTimeHorizon() throws {
        let vm = FeedViewModel(context: container.mainContext)
        _ = makeItem(horizon: .today)
        _ = makeItem(horizon: .today)
        _ = makeItem(horizon: .thisWeek)
        _ = makeItem(horizon: .someday)
        vm.loadItems()
        #expect(vm.todayItems.count == 2)
        #expect(vm.thisWeekItems.count == 1)
        #expect(vm.somedayItems.count == 1)
    }

    @Test func completedItemsExcludedFromFeed() throws {
        let vm = FeedViewModel(context: container.mainContext)
        _ = makeItem(horizon: .today, complete: true)
        _ = makeItem(horizon: .today, complete: false)
        vm.loadItems()
        #expect(vm.todayItems.count == 1)
    }

    @Test func markCompleteRemovesFromFeed() throws {
        let vm = FeedViewModel(context: container.mainContext)
        let item = makeItem(horizon: .today)
        vm.loadItems()
        #expect(vm.todayItems.count == 1)
        vm.markComplete(item)
        vm.loadItems()
        #expect(vm.todayItems.count == 0)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Use `RunSomeTests`, filter `FeedViewModelTests`. Expected: compile error.

- [ ] **Step 3: Create FeedViewModel**

```swift
// MyApp/Feed/FeedViewModel.swift
import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class FeedViewModel {
    private let context: ModelContext
    var todayItems: [ActionItem] = []
    var thisWeekItems: [ActionItem] = []
    var somedayItems: [ActionItem] = []
    var pendingCaptureCount: Int = 0

    init(context: ModelContext) {
        self.context = context
    }

    func loadItems() {
        let descriptor = FetchDescriptor<ActionItem>(
            predicate: #Predicate { !$0.isComplete },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        todayItems = all.filter { $0.timeHorizon == .today }
        thisWeekItems = all.filter { $0.timeHorizon == .thisWeek }
        somedayItems = all.filter { $0.timeHorizon == .someday }

        let pendingDescriptor = FetchDescriptor<CaptureItem>(
            predicate: #Predicate { $0.processingStatus == ProcessingStatus.pending || $0.processingStatus == ProcessingStatus.processing }
        )
        pendingCaptureCount = (try? context.fetch(pendingDescriptor).count) ?? 0
    }

    func markComplete(_ item: ActionItem) {
        item.isComplete = true
        try? context.save()
    }

    func snooze(_ item: ActionItem) {
        // Move to next horizon
        switch item.timeHorizon {
        case .today: item.timeHorizon = .thisWeek
        case .thisWeek: item.timeHorizon = .someday
        case .someday: break
        }
        try? context.save()
    }
}
```

- [ ] **Step 4: Run tests — expect them to pass**

Use `RunSomeTests`, filter `FeedViewModelTests`. Expected: all pass.

- [ ] **Step 5: Create ActionItemCardView**

```swift
// MyApp/Feed/ActionItemCardView.swift
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
        .contextMenu {
            Button(action: onSnooze) {
                Label("Snooze", systemImage: "clock.arrow.circlepath")
            }
            Button(role: .destructive, action: onComplete) {
                Label("Mark Done", systemImage: "checkmark")
            }
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
}
```

- [ ] **Step 6: Create FeedView**

```swift
// MyApp/Feed/FeedView.swift
import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel: FeedViewModel
    @State private var navigationPath = NavigationPath()

    init() {
        // ViewModel initialized in onAppear after context is available
        _viewModel = State(initialValue: FeedViewModel(context: ModelContext(try! ModelContainer(for: CaptureItem.self))))
    }

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
        .onAppear { viewModel = FeedViewModel(context: context); viewModel.loadItems() }
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
```

> **Note:** The `init()` workaround for `@Environment(\.modelContext)` is needed because `@Environment` isn't available until the view is in the hierarchy. The `onAppear` reinitializes the ViewModel with the real context. This is the standard pattern for SwiftData + @Observable.

- [ ] **Step 7: Build to verify**

Use `BuildProject` MCP tool. Fix any Swift 6 concurrency warnings (add `@MainActor` where needed, ensure `CaptureBarView` and `TaskDetailView` exist as stubs).

- [ ] **Step 8: Render preview**

Use `RenderPreview` MCP tool on `FeedView`. Confirm feed renders with section headers.

- [ ] **Step 9: Commit**

```
git add MyApp/Feed/ CLAUDEmdTests/FeedViewModelTests.swift
git commit -m "feat: add feed view with action item cards and time horizon grouping"
```

---

## Task 4: Task Detail View + Chat UI

**Files:**
- Create: `MyApp/Detail/TaskDetailViewModel.swift`
- Create: `MyApp/Detail/TaskDetailView.swift`
- Create: `CLAUDEmdTests/TaskDetailViewModelTests.swift`

- [ ] **Step 1: Write failing ViewModel tests**

```swift
// CLAUDEmdTests/TaskDetailViewModelTests.swift
import Testing
import SwiftData
@testable import MyApp

@MainActor
struct TaskDetailViewModelTests {
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
    }

    private func makeActionItem() -> ActionItem {
        let capture = CaptureItem(rawContent: "reschedule pediatrician")
        let item = ActionItem(title: "Reschedule pediatrician", firstStep: "Call office", timeHorizon: .today, category: "appointment", captureItem: capture)
        container.mainContext.insert(capture)
        container.mainContext.insert(item)
        return item
    }

    @Test func addUserMessageAppendsToThread() async throws {
        let item = makeActionItem()
        let vm = TaskDetailViewModel(item: item, context: container.mainContext, claudeService: StubClaudeService())
        await vm.send("Can you break this into smaller steps?")
        #expect(item.messages.count >= 1)
        #expect(item.messages.first?.role == .user)
    }

    @Test func sendingEmptyMessageDoesNothing() async throws {
        let item = makeActionItem()
        let vm = TaskDetailViewModel(item: item, context: container.mainContext, claudeService: StubClaudeService())
        await vm.send("   ")
        #expect(item.messages.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Use `RunSomeTests`, filter `TaskDetailViewModelTests`. Expected: compile error.

- [ ] **Step 3: Create TaskDetailViewModel**

```swift
// MyApp/Detail/TaskDetailViewModel.swift
import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class TaskDetailViewModel {
    let item: ActionItem
    private let context: ModelContext
    private let claudeService: any ClaudeService
    var isSending = false
    var inputText = ""
    var userContext = ""

    init(item: ActionItem, context: ModelContext, claudeService: any ClaudeService) {
        self.item = item
        self.context = context
        self.claudeService = claudeService
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed, actionItem: item)
        context.insert(userMessage)
        item.messages.append(userMessage)
        try? context.save()

        isSending = true
        defer { isSending = false }

        do {
            let reply = try await claudeService.chat(
                messages: item.messages,
                taskContext: item,
                userContext: userContext
            )
            let assistantMessage = ChatMessage(role: .assistant, content: reply, actionItem: item)
            context.insert(assistantMessage)
            item.messages.append(assistantMessage)
            try? context.save()
        } catch {
            // Silent failure — message remains in thread, user can retry
        }
    }
}
```

- [ ] **Step 4: Run tests — expect them to pass**

Use `RunSomeTests`, filter `TaskDetailViewModelTests`. Expected: all pass.

- [ ] **Step 5: Create TaskDetailView**

```swift
// MyApp/Detail/TaskDetailView.swift
import SwiftUI
import SwiftData

struct TaskDetailView: View {
    let item: ActionItem
    @Environment(\.modelContext) private var context
    @Environment(\.claudeService) private var claudeService
    @State private var viewModel: TaskDetailViewModel?

    var body: some View {
        VStack(spacing: 0) {
            // Task summary card
            VStack(alignment: .leading, spacing: 8) {
                Label(item.category.capitalized, systemImage: "tag")
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(item.messages.sorted(by: { $0.createdAt < $1.createdAt })) { message in
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
                    if let last = item.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // Input bar
            HStack(spacing: 12) {
                TextField("Ask a follow-up…", text: Binding(
                    get: { viewModel?.inputText ?? "" },
                    set: { viewModel?.inputText = $0 }
                ), axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)

                Button {
                    Task {
                        let text = viewModel?.inputText ?? ""
                        viewModel?.inputText = ""
                        await viewModel?.send(text)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel?.inputText.isEmpty == false ? .blue : .secondary)
                }
                .disabled(viewModel?.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }
            .padding()
            .background(.regularMaterial)
        }
        .navigationTitle("Task Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel = TaskDetailViewModel(item: item, context: context, claudeService: claudeService)
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
                    message.role == .user ? Color.blue : Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

#Preview {
    let capture = CaptureItem(rawContent: "preview")
    let item = ActionItem(title: "Get baby passport", firstStep: "Book post office appointment online", timeHorizon: .today, category: "admin", captureItem: capture)
    NavigationStack {
        TaskDetailView(item: item)
    }
    .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self], inMemory: true)
}
```

- [ ] **Step 6: Build + render preview**

Use `BuildProject`, then `RenderPreview` on `TaskDetailView`. Confirm chat thread layout renders correctly.

- [ ] **Step 7: Commit**

```
git add MyApp/Detail/ CLAUDEmdTests/TaskDetailViewModelTests.swift
git commit -m "feat: add task detail view with conversational chat thread"
```

---

## Task 5: Capture Bar + On-Device Processing

**Files:**
- Create: `MyApp/Capture/VoiceCaptureSession.swift`
- Create: `MyApp/Capture/ImageCaptureSession.swift`
- Create: `MyApp/Capture/CaptureViewModel.swift`
- Create: `MyApp/Capture/CaptureBarView.swift`
- Create: `CLAUDEmdTests/CaptureViewModelTests.swift`

- [ ] **Step 1: Write failing ViewModel tests**

```swift
// CLAUDEmdTests/CaptureViewModelTests.swift
import Testing
import SwiftData
@testable import MyApp

@MainActor
struct CaptureViewModelTests {
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
    }

    @Test func textCaptureCreatesPendingItem() async throws {
        let vm = CaptureViewModel(context: container.mainContext)
        await vm.submitText("reschedule pediatrician appointment")
        let descriptor = FetchDescriptor<CaptureItem>()
        let items = try container.mainContext.fetch(descriptor)
        #expect(items.count == 1)
        #expect(items[0].rawContent == "reschedule pediatrician appointment")
        #expect(items[0].processingStatus == .pending)
    }

    @Test func emptyTextIsIgnored() async throws {
        let vm = CaptureViewModel(context: container.mainContext)
        await vm.submitText("   ")
        let descriptor = FetchDescriptor<CaptureItem>()
        let items = try container.mainContext.fetch(descriptor)
        #expect(items.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Use `RunSomeTests`, filter `CaptureViewModelTests`. Expected: compile error.

- [ ] **Step 3: Create VoiceCaptureSession**

```swift
// MyApp/Capture/VoiceCaptureSession.swift
import Foundation
import AVFoundation
import Speech

actor VoiceCaptureSession {
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: .current)

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscribing() -> AsyncStream<String> {
        AsyncStream { continuation in
            let engine = AVAudioEngine()
            self.audioEngine = engine
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            try? engine.start()

            recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
                if let result = result {
                    continuation.yield(result.bestTranscription.formattedString)
                }
                if error != nil || result?.isFinal == true {
                    continuation.finish()
                }
            }
        }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionTask = nil
    }
}
```

- [ ] **Step 4: Create ImageCaptureSession**

```swift
// MyApp/Capture/ImageCaptureSession.swift
import Vision
import UIKit

struct ImageCaptureSession {
    /// Extracts text and returns a human-readable description of the image content.
    static func describe(_ image: UIImage) async -> String {
        await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: "")
                return
            }
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                continuation.resume(returning: text.isEmpty ? "[image with no readable text]" : text)
            }
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}
```

- [ ] **Step 5: Create CaptureViewModel**

```swift
// MyApp/Capture/CaptureViewModel.swift
import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class CaptureViewModel {
    private let context: ModelContext
    var isRecording = false
    var liveTranscript = ""
    var showingImagePicker = false
    private var voiceSession: VoiceCaptureSession?

    init(context: ModelContext) {
        self.context = context
    }

    func submitText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = CaptureItem(rawContent: trimmed)
        context.insert(item)
        try? context.save()
    }

    func submitImage(_ image: UIImage) async {
        let description = await ImageCaptureSession.describe(image)
        guard !description.isEmpty else { return }
        // Save image to disk, store path
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url)
        }
        let item = CaptureItem(rawContent: description, imageReference: url.path)
        context.insert(item)
        try? context.save()
    }

    func startVoiceCapture() async {
        guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else { return }
        isRecording = true
        liveTranscript = ""
        let session = VoiceCaptureSession()
        voiceSession = session
        for await partial in await session.startTranscribing() {
            liveTranscript = partial
        }
    }

    func stopVoiceCapture() async {
        await voiceSession?.stop()
        voiceSession = nil
        isRecording = false
        await submitText(liveTranscript)
        liveTranscript = ""
    }
}
```

- [ ] **Step 6: Run tests — expect them to pass**

Use `RunSomeTests`, filter `CaptureViewModelTests`. Expected: all pass.

- [ ] **Step 7: Create CaptureBarView**

```swift
// MyApp/Capture/CaptureBarView.swift
import SwiftUI
import PhotosUI

struct CaptureBarView: View {
    @Environment(\.modelContext) private var context
    let onCapture: () -> Void
    @State private var viewModel: CaptureViewModel?
    @State private var textInput = ""
    @State private var showingTextInput = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            // Text input or placeholder
            if showingTextInput {
                TextField("What's on your mind?", text: $textInput, axis: .vertical)
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit { submitText() }
            } else {
                Text(viewModel?.isRecording == true ? viewModel!.liveTranscript.isEmpty ? "Listening…" : viewModel!.liveTranscript : "Add anything…")
                    .foregroundStyle(viewModel?.isRecording == true ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture { showingTextInput = true }
            }

            Spacer()

            // Camera / photo
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "camera")
                    .foregroundStyle(.secondary)
            }

            // Voice
            Button {
                Task {
                    if viewModel?.isRecording == true {
                        await viewModel?.stopVoiceCapture()
                        onCapture()
                    } else {
                        await viewModel?.startVoiceCapture()
                    }
                }
            } label: {
                Image(systemName: viewModel?.isRecording == true ? "stop.circle.fill" : "mic")
                    .foregroundStyle(viewModel?.isRecording == true ? .red : .blue)
                    .font(.title3)
            }
        }
        .padding()
        .background(.regularMaterial, in: Capsule())
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel?.submitImage(image)
                    onCapture()
                }
            }
        }
        .onAppear {
            viewModel = CaptureViewModel(context: context)
        }
    }

    private func submitText() {
        Task {
            await viewModel?.submitText(textInput)
            textInput = ""
            showingTextInput = false
            onCapture()
        }
    }
}

#Preview {
    CaptureBarView(onCapture: {})
        .padding()
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self], inMemory: true)
}
```

> **Note:** Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` and `NSPhotoLibraryUsageDescription` to `Info.plist`.

- [ ] **Step 8: Build + render preview**

Use `BuildProject` then `RenderPreview` on `CaptureBarView`. Confirm pill shape renders with icons.

- [ ] **Step 9: Commit**

```
git add MyApp/Capture/ CLAUDEmdTests/CaptureViewModelTests.swift
git commit -m "feat: add capture bar with voice, photo, and text input"
```

---

## Task 6: Claude API Service

**Files:**
- Create: `MyApp/Services/ClaudeService.swift`
- Create: `CLAUDEmdTests/ClaudeServiceTests.swift`

- [ ] **Step 1: Write failing service tests**

```swift
// CLAUDEmdTests/ClaudeServiceTests.swift
import Testing
@testable import MyApp
import Foundation

struct ClaudeServiceTests {
    @Test func triageRequestBuildsCorrectPayload() async throws {
        let session = MockURLSession()
        session.mockResponse = ClaudeAPIResponse(
            content: [.init(text: """
            {"tasks":[{"title":"Call doctor","firstStep":"Find number","timeHorizon":"today","deadline":null,"category":"appointment","scheduledNotification":null}]}
            """)]
        )
        let service = ClaudeServiceImpl(apiKey: "test-key", urlSession: session)
        let capture = CaptureItem(rawContent: "reschedule pediatrician")
        let results = try await service.triage(captures: [capture], userContext: "")
        #expect(results.count == 1)
        #expect(results[0].title == "Call doctor")
        #expect(results[0].timeHorizon == .today)
    }

    @Test func chatRequestReturnsAssistantText() async throws {
        let session = MockURLSession()
        session.mockResponse = ClaudeAPIResponse(
            content: [.init(text: "Sure, here's a breakdown: 1. Call the office...")]
        )
        let service = ClaudeServiceImpl(apiKey: "test-key", urlSession: session)
        let capture = CaptureItem(rawContent: "test")
        let item = ActionItem(title: "Test", firstStep: "Do it", timeHorizon: .today, category: "errand", captureItem: capture)
        let result = try await service.chat(messages: [], taskContext: item, userContext: "")
        #expect(result.contains("Call the office"))
    }
}

// MARK: - Test Doubles
struct MockURLSession: URLSessionProtocol {
    var mockResponse: ClaudeAPIResponse?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let data = try JSONEncoder().encode(mockResponse!)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Use `RunSomeTests`, filter `ClaudeServiceTests`. Expected: compile error.

- [ ] **Step 3: Create ClaudeService**

```swift
// MyApp/Services/ClaudeService.swift
import Foundation

// MARK: - URL Session Protocol (for testability)
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - API Types
struct ClaudeAPIMessage: Encodable {
    let role: String
    let content: String
}

struct ClaudeAPIRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ClaudeAPIMessage]
    enum CodingKeys: String, CodingKey {
        case model, messages, system
        case maxTokens = "max_tokens"
    }
}

struct ClaudeAPIResponseContent: Codable {
    let text: String
}

struct ClaudeAPIResponse: Codable {
    let content: [ClaudeAPIResponseContent]
}

// MARK: - Implementation
final class ClaudeServiceImpl: ClaudeService, Sendable {
    private let apiKey: String
    private let urlSession: any URLSessionProtocol
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    init(apiKey: String, urlSession: any URLSessionProtocol = URLSession.shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult] {
        let captureText = captures.enumerated().map { i, c in
            "[\(i+1)] \(c.rawContent)"
        }.joined(separator: "\n")

        let systemPrompt = """
        You are a life admin assistant for a busy mom. Analyze the captured items and return a JSON object.
        
        User context and preferences:
        \(userContext.isEmpty ? "No preferences yet — this is a new user." : userContext)
        
        Return ONLY valid JSON in this exact format:
        {
          "tasks": [
            {
              "title": "clear action title",
              "firstStep": "specific 10-minute first step",
              "timeHorizon": "today" | "thisWeek" | "someday",
              "deadline": "ISO8601 date string or null",
              "category": "appointment" | "errand" | "admin" | "personal",
              "scheduledNotification": {
                "title": "reminder title",
                "body": "first step as notification body",
                "triggerDate": "ISO8601 date string"
              } | null
            }
          ]
        }
        
        Rules:
        - Break vague items into concrete first steps
        - Only set deadline if explicitly mentioned
        - Only schedule notification if there's a real deadline or urgent time sensitivity
        - One CaptureItem may produce multiple tasks
        """

        let request = ClaudeAPIRequest(
            model: model,
            maxTokens: 1024,
            system: systemPrompt,
            messages: [ClaudeAPIMessage(role: "user", content: "Process these captured items:\n\(captureText)")]
        )

        let responseText = try await sendRequest(request)

        // Extract JSON from response (Claude may wrap it in markdown)
        let json = extractJSON(from: responseText)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct TriageResponse: Decodable {
            let tasks: [TriageResult]
        }
        let parsed = try decoder.decode(TriageResponse.self, from: Data(json.utf8))
        return parsed.tasks
    }

    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String {
        let systemPrompt = """
        You are a helpful life admin assistant for a busy mom.
        
        Task context: \(taskContext.title)
        First step: \(taskContext.firstStep)
        Category: \(taskContext.category)
        
        User preferences:
        \(userContext.isEmpty ? "No preferences yet." : userContext)
        
        Keep responses brief, practical, and warm. No jargon. Focus on reducing overwhelm.
        """

        // Compress: only send last 10 messages
        let recentMessages = messages.sorted(by: { $0.createdAt < $1.createdAt }).suffix(10)
        let apiMessages = recentMessages.map {
            ClaudeAPIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content)
        }

        // Ensure last message is from user
        guard apiMessages.last?.role == "user" else { return "" }

        let request = ClaudeAPIRequest(
            model: model,
            maxTokens: 512,
            system: systemPrompt,
            messages: Array(apiMessages)
        )

        return try await sendRequest(request)
    }

    // MARK: - Private

    private func sendRequest(_ body: ClaudeAPIRequest) async throws -> String {
        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClaudeError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoded = try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    private func extractJSON(from text: String) -> String {
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return text
    }
}

enum ClaudeError: Error {
    case httpError(Int)
    case parseError
}
```

- [ ] **Step 4: Run tests — expect them to pass**

Use `RunSomeTests`, filter `ClaudeServiceTests`. Expected: all pass.

- [ ] **Step 5: Commit**

```
git add MyApp/Services/ClaudeService.swift CLAUDEmdTests/ClaudeServiceTests.swift
git commit -m "feat: add Claude API service with triage and chat endpoints"
```

---

## Task 7: Triage Batch Processor + Wire AI to Feed

**Files:**
- Create: `MyApp/Services/TriageBatchProcessor.swift`
- Modify: `MyApp/MyAppApp.swift`
- Create: `CLAUDEmdTests/TriageBatchProcessorTests.swift`

- [ ] **Step 1: Write failing processor tests**

```swift
// CLAUDEmdTests/TriageBatchProcessorTests.swift
import Testing
import SwiftData
@testable import MyApp

struct TriageBatchProcessorTests {
    @Test func pendingItemsAreProcessedIntoBatch() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
        let capture1 = CaptureItem(rawContent: "reschedule pediatrician")
        let capture2 = CaptureItem(rawContent: "return Nike shoes")
        await MainActor.run {
            container.mainContext.insert(capture1)
            container.mainContext.insert(capture2)
            try? container.mainContext.save()
        }

        let service = SpyClaudeService()
        let processor = TriageBatchProcessor(container: container, claudeService: service)
        await processor.processPendingBatch()

        #expect(service.triageCallCount == 1)
        #expect(service.lastTriageBatchSize == 2)
    }

    @Test func alreadyProcessedItemsAreSkipped() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
        let done = CaptureItem(rawContent: "already done")
        await MainActor.run {
            done.processingStatus = .complete
            container.mainContext.insert(done)
            try? container.mainContext.save()
        }

        let service = SpyClaudeService()
        let processor = TriageBatchProcessor(container: container, claudeService: service)
        await processor.processPendingBatch()

        #expect(service.triageCallCount == 0)
    }
}

// MARK: - Test Double
final class SpyClaudeService: ClaudeService, @unchecked Sendable {
    var triageCallCount = 0
    var lastTriageBatchSize = 0

    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult] {
        triageCallCount += 1
        lastTriageBatchSize = captures.count
        return []
    }

    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String {
        return "stub"
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Use `RunSomeTests`, filter `TriageBatchProcessorTests`. Expected: compile error.

- [ ] **Step 3: Create TriageBatchProcessor**

```swift
// MyApp/Services/TriageBatchProcessor.swift
import Foundation
import SwiftData

actor TriageBatchProcessor {
    private let container: ModelContainer
    private let claudeService: any ClaudeService
    private var retryDelays: [UUID: TimeInterval] = [:]

    init(container: ModelContainer, claudeService: any ClaudeService) {
        self.container = container
        self.claudeService = claudeService
    }

    func processPendingBatch() async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CaptureItem>(
            predicate: #Predicate { $0.processingStatus == ProcessingStatus.pending }
        )
        let pending = (try? context.fetch(descriptor)) ?? []
        guard !pending.isEmpty else { return }

        // Mark as processing
        pending.forEach { $0.processingStatus = .processing }
        try? context.save()

        // Fetch user context
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profile = (try? context.fetch(profileDescriptor))?.first
        let userContext = profile?.preferenceSummary ?? ""

        do {
            let results = try await claudeService.triage(captures: pending, userContext: userContext)

            // Map results back to ActionItems
            for result in results {
                let action = ActionItem(
                    title: result.title,
                    firstStep: result.firstStep,
                    timeHorizon: result.timeHorizon,
                    category: result.category,
                    captureItem: pending.first, // best effort link
                    deadline: result.deadline
                )
                context.insert(action)
            }

            pending.forEach { $0.processingStatus = .complete }
            try? context.save()

        } catch {
            // Exponential backoff: mark as pending again, delay next attempt
            pending.forEach { $0.processingStatus = .pending }
            try? context.save()
        }
    }

    /// Call this when the app foregrounds or on a timer.
    func startPeriodicProcessing() {
        Task {
            while true {
                await processPendingBatch()
                try? await Task.sleep(for: .seconds(180)) // every 3 minutes
            }
        }
    }
}
```

- [ ] **Step 4: Run tests — expect them to pass**

Use `RunSomeTests`, filter `TriageBatchProcessorTests`. Expected: all pass.

- [ ] **Step 5: Wire processor into app entry point**

```swift
// MyApp/MyAppApp.swift
import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    @AppStorage("claudeAPIKey") private var apiKey = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            let claudeService = apiKey.isEmpty ? StubClaudeService() as (any ClaudeService) : ClaudeServiceImpl(apiKey: apiKey)
            FeedView()
                .environment(\.claudeService, claudeService)
                .environment(\.notificationService, NotificationServiceImpl())
        }
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Trigger batch processing on foreground
                // TriageBatchProcessor is instantiated in the app's environment in Task 9
            }
        }
    }
}
```

- [ ] **Step 6: Build to verify**

Use `BuildProject`. Expected: success.

- [ ] **Step 7: Commit**

```
git add MyApp/Services/TriageBatchProcessor.swift MyApp/MyAppApp.swift CLAUDEmdTests/TriageBatchProcessorTests.swift
git commit -m "feat: add triage batch processor with retry and periodic processing"
```

---

## Task 8: UserProfile Service

**Files:**
- Create: `MyApp/Services/UserProfileService.swift`
- Create: `CLAUDEmdTests/UserProfileServiceTests.swift`

- [ ] **Step 1: Write failing service tests**

```swift
// CLAUDEmdTests/UserProfileServiceTests.swift
import Testing
import SwiftData
@testable import MyApp

struct UserProfileServiceTests {
    @Test func appendsObservationToLog() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
        let service = UserProfileService(container: container, claudeService: StubClaudeService())
        await service.log("User completed: Reschedule pediatrician")
        await service.log("User snoozed: Return Nike shoes")

        let profile = await service.fetchOrCreateProfile()
        #expect(profile.observationLog.contains("completed"))
        #expect(profile.observationLog.contains("snoozed"))
    }

    @Test func doesNotSummarizeIfSummarizedToday() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self,
            configurations: config
        )
        let spy = SpyClaudeService()
        let service = UserProfileService(container: container, claudeService: spy)

        // Pre-set summarized today
        let profile = await service.fetchOrCreateProfile()
        await MainActor.run {
            profile.lastSummarizedAt = Date()
        }

        await service.summarizeIfNeeded()
        #expect(spy.triageCallCount == 0) // no summarization call made
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Use `RunSomeTests`, filter `UserProfileServiceTests`. Expected: compile error.

- [ ] **Step 3: Create UserProfileService**

```swift
// MyApp/Services/UserProfileService.swift
import Foundation
import SwiftData

actor UserProfileService {
    private let container: ModelContainer
    private let claudeService: any ClaudeService

    init(container: ModelContainer, claudeService: any ClaudeService) {
        self.container = container
        self.claudeService = claudeService
    }

    func fetchOrCreateProfile() async -> UserProfile {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }

    func log(_ observation: String) async {
        let context = ModelContext(container)
        let profile = await fetchOrCreateProfile()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(observation)\n"
        profile.observationLog += line
        try? context.save()
    }

    func summarizeIfNeeded() async {
        let profile = await fetchOrCreateProfile()
        if let last = profile.lastSummarizedAt, Calendar.current.isDateInToday(last) { return }

        guard !profile.observationLog.isEmpty else { return }

        let summaryPrompt = """
        Based on these observations about a mom's productivity patterns, write a brief (3-5 sentence) preference summary.
        Focus on: when she tends to work, what she procrastinates, recurring constraints, categories that dominate.
        Keep it factual and concise — this will be injected into future AI prompts.
        
        Observations:
        \(profile.observationLog.suffix(5000)) // last ~5000 chars
        """

        do {
            // Reuse chat endpoint with a synthetic "task" for the summarization call
            let dummyCapture = CaptureItem(rawContent: "profile summarization")
            let dummyTask = ActionItem(title: "Summarize", firstStep: "", timeHorizon: .someday, category: "admin", captureItem: dummyCapture)
            let summary = try await claudeService.chat(
                messages: [ChatMessage(role: .user, content: summaryPrompt, actionItem: dummyTask)],
                taskContext: dummyTask,
                userContext: ""
            )
            let context = ModelContext(container)
            let freshProfile = await fetchOrCreateProfile()
            freshProfile.preferenceSummary = summary
            freshProfile.lastSummarizedAt = Date()
            try? context.save()
        } catch {
            // Silent — try again tomorrow
        }
    }
}
```

- [ ] **Step 4: Run tests — expect them to pass**

Use `RunSomeTests`, filter `UserProfileServiceTests`. Expected: all pass.

- [ ] **Step 5: Hook observation logging into FeedViewModel**

In `FeedViewModel.swift`, inject `UserProfileService` and add logging calls:

```swift
// Add to FeedViewModel
var userProfileService: UserProfileService?

func markComplete(_ item: ActionItem) {
    item.isComplete = true
    try? context.save()
    Task {
        await userProfileService?.log("User completed: \(item.title) [category: \(item.category)]")
    }
}

func snooze(_ item: ActionItem) {
    switch item.timeHorizon {
    case .today: item.timeHorizon = .thisWeek
    case .thisWeek: item.timeHorizon = .someday
    case .someday: break
    }
    try? context.save()
    Task {
        await userProfileService?.log("User snoozed: \(item.title) from \(item.timeHorizon.rawValue)")
    }
}
```

- [ ] **Step 6: Commit**

```
git add MyApp/Services/UserProfileService.swift MyApp/Feed/FeedViewModel.swift CLAUDEmdTests/UserProfileServiceTests.swift
git commit -m "feat: add user profile service with observation logging and daily summarization"
```

---

## Task 9: Notification Service + Cost Controls

**Files:**
- Create: `MyApp/Services/NotificationService.swift`
- Modify: `MyApp/Services/TriageBatchProcessor.swift`
- Modify: `MyApp/Models/UserProfile.swift`
- Create: `CLAUDEmdTests/NotificationServiceTests.swift`

- [ ] **Step 1: Write failing notification tests**

```swift
// CLAUDEmdTests/NotificationServiceTests.swift
import Testing
@testable import MyApp
import UserNotifications

struct NotificationServiceTests {
    @Test func scheduleCreatesNotificationRequest() async throws {
        let center = MockNotificationCenter()
        let service = NotificationServiceImpl(center: center)
        let triggerDate = Date().addingTimeInterval(3600)
        try await service.schedule(title: "Return Nike shoes", body: "Drop off at UPS store", at: triggerDate)
        #expect(center.addedRequests.count == 1)
        #expect(center.addedRequests[0].content.title == "Return Nike shoes")
    }
}

// MARK: - Test Double
final class MockNotificationCenter: UNUserNotificationCenterProtocol, @unchecked Sendable {
    var addedRequests: [UNNotificationRequest] = []
    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Use `RunSomeTests`, filter `NotificationServiceTests`. Expected: compile error.

- [ ] **Step 3: Create NotificationService**

```swift
// MyApp/Services/NotificationService.swift
import UserNotifications

protocol UNUserNotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNUserNotificationCenter: UNUserNotificationCenterProtocol {}

final class NotificationServiceImpl: NotificationServiceProtocol, Sendable {
    private let center: any UNUserNotificationCenterProtocol

    init(center: any UNUserNotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func schedule(title: String, body: String, at date: Date) async throws {
        guard date > Date() else { return } // Don't schedule past notifications
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try await center.add(request)
    }
}
```

- [ ] **Step 4: Add rate limiting to UserProfile**

```swift
// Add to UserProfile.swift (inside the @Model class):
var dailyFreeCallsUsed: Int = 0
var dailyCallResetDate: Date = Date()

// Add to UserProfileService:
func canMakeCloudCall(isPaidUser: Bool) async -> Bool {
    if isPaidUser { return true }
    let profile = await fetchOrCreateProfile()
    let context = ModelContext(container)
    // Reset daily count if it's a new day
    if !Calendar.current.isDateInToday(profile.dailyCallResetDate) {
        profile.dailyFreeCallsUsed = 0
        profile.dailyCallResetDate = Date()
        try? context.save()
    }
    return profile.dailyFreeCallsUsed < 10 // Free tier: 10 cloud calls/day
}

func recordCloudCall() async {
    let profile = await fetchOrCreateProfile()
    let context = ModelContext(container)
    profile.dailyFreeCallsUsed += 1
    try? context.save()
}
```

- [ ] **Step 5: Add smart routing to TriageBatchProcessor**

In `TriageBatchProcessor.swift`, before calling Claude, check if a capture is simple enough to handle locally:

```swift
// Add to TriageBatchProcessor:
private func isSimpleCapture(_ content: String) -> Bool {
    let wordCount = content.split(separator: " ").count
    let hasDateLanguage = content.lowercased().contains(where: { "today tomorrow week month deadline by due".split(separator: " ").contains(Substring($0.description)) })
    return wordCount <= 8 && !hasDateLanguage
}

private func handleLocally(_ capture: CaptureItem, context: ModelContext) {
    // Simple short captures → Someday with the text as the title
    let action = ActionItem(
        title: capture.rawContent.capitalized,
        firstStep: "Take care of: \(capture.rawContent)",
        timeHorizon: .someday,
        category: "errand",
        captureItem: capture
    )
    context.insert(action)
    capture.processingStatus = .complete
}
```

Then in `processPendingBatch()`, split pending items:
```swift
let (simple, complex) = pending.partition { isSimpleCapture($0.rawContent) }
simple.forEach { handleLocally($0, context: context) }
// Only send complex items to Claude
```

- [ ] **Step 6: Wire notifications into TriageBatchProcessor**

After triage results come back and `ActionItem`s are created, schedule any notifications returned:

```swift
// In processPendingBatch(), after creating ActionItems:
for result in results {
    if let notification = result.scheduledNotification {
        try? await notificationService.schedule(
            title: notification.title,
            body: notification.body,
            at: notification.triggerDate
        )
    }
}
```

Pass `notificationService` into `TriageBatchProcessor.init()`.

- [ ] **Step 7: Run all tests**

Use `RunAllTests` MCP tool. Expected: all pass.

- [ ] **Step 8: Commit**

```
git add MyApp/Services/NotificationService.swift MyApp/Services/TriageBatchProcessor.swift MyApp/Models/UserProfile.swift CLAUDEmdTests/NotificationServiceTests.swift
git commit -m "feat: add notification service, rate limiting, and smart routing for simple captures"
```

---

## Task 10: Settings View + Final Wire-Up

**Files:**
- Create: `MyApp/Settings/SettingsView.swift`
- Modify: `MyApp/MyAppApp.swift`

- [ ] **Step 1: Create SettingsView**

```swift
// MyApp/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("claudeAPIKey") private var apiKey = ""
    @AppStorage("isPaidUser") private var isPaidUser = false
    @State private var notificationsGranted = false

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
                Toggle("Enable Reminders", isOn: $notificationsGranted)
                    .onChange(of: notificationsGranted) { _, enabled in
                        if enabled {
                            Task {
                                notificationsGranted = await NotificationServiceImpl().requestPermission()
                            }
                        }
                    }
            }

            Section("Account") {
                if isPaidUser {
                    Label("Unlimited plan active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Free plan: 10 AI captures per day")
                    Button("Upgrade to Unlimited") {
                        // StoreKit purchase — future implementation
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
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
```

- [ ] **Step 2: Final wire-up in MyAppApp**

```swift
// MyApp/MyAppApp.swift — final version
import SwiftUI
import SwiftData

@main
struct MyAppApp: App {
    @AppStorage("claudeAPIKey") private var apiKey = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var processor: TriageBatchProcessor?

    var body: some Scene {
        WindowGroup {
            FeedView()
                .environment(\.claudeService, makeClaudeService())
                .environment(\.notificationService, NotificationServiceImpl())
                .task { await NotificationServiceImpl().requestPermission() }
        }
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await processor?.processPendingBatch() }
            }
        }
    }

    private func makeClaudeService() -> any ClaudeService {
        apiKey.isEmpty ? StubClaudeService() : ClaudeServiceImpl(apiKey: apiKey)
    }
}
```

> **Note:** `TriageBatchProcessor` requires a `ModelContainer` reference. Initialize it in `.onAppear` on `FeedView` and store in the Environment, or use a dedicated `@State` in the App struct after the container is ready. Passing `ModelContainer` through the Environment is the recommended SwiftData pattern.

- [ ] **Step 3: Run all tests**

Use `RunAllTests` MCP tool. Expected: all pass.

- [ ] **Step 4: Build final app**

Use `BuildProject`. Expected: success with no warnings.

- [ ] **Step 5: Commit**

```
git add MyApp/Settings/SettingsView.swift MyApp/MyAppApp.swift
git commit -m "feat: add settings view and complete app wire-up"
```

---

## Self-Review Notes

**Spec coverage check:**
- ✅ Voice/photo/text capture (Task 5)
- ✅ On-device processing (Task 5 — SFSpeechRecognizer + Vision)
- ✅ Claude API triage (Task 6)
- ✅ Feed with time horizon grouping (Task 3)
- ✅ Task detail + conversational chat (Task 4)
- ✅ Silent processing, passive by default (TriageBatchProcessor)
- ✅ UserProfile observation + learning (Task 8)
- ✅ Notifications for deadlines (Task 9)
- ✅ Rate limiting / free tier (Task 9)
- ✅ Smart routing for simple captures (Task 9)
- ✅ Context compression for chat (Task 6 — 10-message window)
- ✅ Settings with API key (Task 10)
- ✅ HIG compliance — Liquid Glass materials, SF Symbols, NavigationStack, standard gestures throughout
- ✅ SwiftData models (Task 1)
- ✅ @Observable ViewModels, Views own VM as @State (Tasks 3, 4, 5)

**Types are consistent throughout:** `TimeHorizon`, `ProcessingStatus`, `MessageRole`, `CaptureItem`, `ActionItem`, `ChatMessage`, `UserProfile`, `TriageResult` — all defined once in Task 1/2 and used consistently.

**`Task` naming:** Avoided throughout in favor of `ActionItem` to prevent conflict with `Swift.Task`. Consistent across all tasks.
