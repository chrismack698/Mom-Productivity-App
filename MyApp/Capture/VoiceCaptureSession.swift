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

            self.recognitionTask = self.recognizer?.recognitionTask(with: request) { result, error in
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
