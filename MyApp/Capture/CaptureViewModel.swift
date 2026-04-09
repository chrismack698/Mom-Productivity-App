// MyApp/Capture/CaptureViewModel.swift
import SwiftUI
import SwiftData
import Observation
import Speech

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
