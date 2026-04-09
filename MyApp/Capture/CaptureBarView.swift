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

            // Camera / photo picker
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "camera")
                    .foregroundStyle(.secondary)
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
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel?.submitImage(image)
                    photoItem = nil
                    onCapture()
                }
            }
        }
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
        .modelContainer(for: [CaptureItem.self, ActionItem.self, ChatMessage.self, UserProfile.self], inMemory: true)
}
