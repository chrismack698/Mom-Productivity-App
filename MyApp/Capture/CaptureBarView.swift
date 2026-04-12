// MyApp/Capture/CaptureBarView.swift
import SwiftUI

struct CaptureBarView: View {
    @Environment(\.modelContext) private var context
    let onCapture: () -> Void
    @State private var viewModel: CaptureViewModel?
    @State private var textInput = ""
    @State private var showingTextInput = false

    var body: some View {
        HStack(spacing: 12) {
            if showingTextInput {
                TextField("What's on your mind?", text: $textInput, axis: .vertical)
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit { submitText() }
            } else {
                Text(promptText)
                    .foregroundStyle(viewModel?.isRecording == true ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture { showingTextInput = true }
            }
            // Voice button
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
                    .foregroundStyle(viewModel?.isRecording == true ? Color.red : Color.blue)
                    .font(.title3)
            }
        }
        .padding()
        .background(.regularMaterial, in: Capsule())
        .onAppear {
            viewModel = CaptureViewModel(context: context)
        }
    }

    private var promptText: String {
        if viewModel?.isRecording == true {
            let transcript = viewModel?.liveTranscript ?? ""
            return transcript.isEmpty ? "Listening…" : transcript
        }
        return "Add anything…"
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
