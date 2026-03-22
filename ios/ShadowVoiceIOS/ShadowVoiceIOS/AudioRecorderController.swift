import AVFoundation
import Combine
import Foundation

enum AudioRecorderError: LocalizedError {
    case microphonePermissionDenied
    case recorderFailedToStart
    case missingRecording

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required to record pronunciation audio."
        case .recorderFailedToStart:
            return "The app could not start a WAV recording."
        case .missingRecording:
            return "No recorded WAV file is available yet."
        }
    }
}

@MainActor
final class AudioRecorderController: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordedFileURL: URL?

    private var recorder: AVAudioRecorder?

    func startRecording() async throws {
        let granted = await requestPermission()
        guard granted else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let outputURL = recordingURL()
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw AudioRecorderError.recorderFailedToStart
        }

        self.recorder = recorder
        self.recordedFileURL = outputURL
        self.isRecording = true
    }

    func stopRecording() throws -> URL {
        guard let recorder else {
            throw AudioRecorderError.missingRecording
        }

        recorder.stop()
        self.recorder = nil
        self.isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        guard let recordedFileURL else {
            throw AudioRecorderError.missingRecording
        }

        return recordedFileURL
    }

    func recordedAudioData() throws -> Data {
        guard let recordedFileURL else {
            throw AudioRecorderError.missingRecording
        }
        return try Data(contentsOf: recordedFileURL)
    }

    private func recordingURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("shadowvoice-user-audio.wav")
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
