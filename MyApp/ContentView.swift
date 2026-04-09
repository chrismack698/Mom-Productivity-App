import SwiftUI

struct ContentView: View {
    var body: some View {
        FeedView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self], inMemory: true)
}
