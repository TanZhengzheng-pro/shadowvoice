import Combine
import Foundation

import ShadowVoiceClientCore

@MainActor
final class AnalyzeViewModel: ObservableObject {
    @Published var backendURL = "http://127.0.0.1:8000"
    @Published var targetText = "shadow voice"
    @Published private(set) var statusMessage = "Record a clip, then send it to the backend."
    @Published private(set) var errorMessage: String?
    @Published private(set) var analysisResult: AnalyzeResponse?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var referenceAudioName: String?

    let recorder = AudioRecorderController()

    private let apiClient = ShadowVoiceAPIClient()
    private var referenceAudioData: Data?

    var canAnalyze: Bool {
        !isAnalyzing
        && !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && recorder.recordedFileURL != nil
    }

    var userAudioCaption: String {
        if let fileName = recorder.recordedFileURL?.lastPathComponent {
            return fileName
        }
        return "No user audio recorded yet."
    }

    func toggleRecording() async {
        if recorder.isRecording {
            stopRecording()
            return
        }

        do {
            try await recorder.startRecording()
            errorMessage = nil
            analysisResult = nil
            statusMessage = "Recording user audio..."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Unable to start recording."
        }
    }

    func stopRecording() {
        do {
            let recordingURL = try recorder.stopRecording()
            errorMessage = nil
            analysisResult = nil
            statusMessage = "User audio saved as \(recordingURL.lastPathComponent)."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "No recording was saved."
        }
    }

    func importReferenceAudio(from url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            referenceAudioData = data
            referenceAudioName = url.lastPathComponent
            errorMessage = nil
            analysisResult = nil
            statusMessage = "Loaded optional reference audio."
        } catch {
            errorMessage = "Unable to read the selected WAV file."
            statusMessage = "Reference import failed."
        }
    }

    func importReferenceAudioFailure(_ error: Error) {
        errorMessage = error.localizedDescription
        statusMessage = "Reference import failed."
    }

    func clearReferenceAudio() {
        referenceAudioData = nil
        referenceAudioName = nil
        statusMessage = "Reference audio cleared."
    }

    func analyze() async {
        guard canAnalyze else {
            errorMessage = "Record user audio and enter target text before analyzing."
            return
        }

        isAnalyzing = true
        errorMessage = nil
        statusMessage = "Sending audio to the backend..."

        do {
            let userAudioData = try recorder.recordedAudioData()
            let response = try await apiClient.analyze(
                baseURLString: backendURL,
                targetText: targetText,
                userAudioData: userAudioData,
                referenceAudioData: referenceAudioData
            )
            analysisResult = response
            statusMessage = "Analysis complete."
        } catch {
            analysisResult = nil
            errorMessage = error.localizedDescription
            statusMessage = "Analysis failed."
        }

        isAnalyzing = false
    }
}
