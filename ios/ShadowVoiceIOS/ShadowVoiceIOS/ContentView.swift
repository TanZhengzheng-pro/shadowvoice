import SwiftUI
import UniformTypeIdentifiers

import ShadowVoiceClientCore

struct ContentView: View {
    @StateObject private var viewModel = AnalyzeViewModel()
    @State private var showingReferenceImporter = false

    private let wavType = UTType(filenameExtension: "wav") ?? .audio

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    connectionCard
                    recordingCard
                    referenceCard
                    analyzeCard

                    if let result = viewModel.analysisResult {
                        resultsCard(result)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(message: errorMessage)
                    }
                }
                .padding(20)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle("ShadowVoice")
        }
        .fileImporter(
            isPresented: $showingReferenceImporter,
            allowedContentTypes: [wavType],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.importReferenceAudio(from: url)
            case .failure(let error):
                viewModel.importReferenceAudioFailure(error)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Pronunciation feedback on top of the local FastAPI scorer.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Record a WAV sample, optionally attach a reference WAV, and send everything to `/analyze`.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))

                StatusPill(text: viewModel.statusMessage)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.16, blue: 0.34),
                    Color(red: 0.18, green: 0.47, blue: 0.42),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var connectionCard: some View {
        SectionCard(title: "Session") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledField(label: "Backend URL", text: $viewModel.backendURL, prompt: "http://127.0.0.1:8000")
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                LabeledField(label: "Target Text", text: $viewModel.targetText, prompt: "shadow voice")
            }
        }
    }

    private var recordingCard: some View {
        SectionCard(title: "User Audio") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Button {
                        Task {
                            await viewModel.toggleRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(viewModel.recorder.isRecording ? Color.red : Color.black)
                                .frame(width: 72, height: 72)

                            Image(systemName: viewModel.recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.recorder.isRecording ? "Recording in progress" : "Record practice audio")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))

                        Text(viewModel.userAudioCaption)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.recorder.isRecording {
                    Text("Tap again to stop and save the WAV file locally inside the app sandbox.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var referenceCard: some View {
        SectionCard(title: "Reference Audio") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Optional. Import a WAV file if you want the backend to compare against a reference speaker.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Import WAV") {
                        showingReferenceImporter = true
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle(tint: Color(red: 0.11, green: 0.39, blue: 0.64)))

                    if viewModel.referenceAudioName != nil {
                        Button("Clear") {
                            viewModel.clearReferenceAudio()
                        }
                        .buttonStyle(SecondaryCapsuleButtonStyle())
                    }
                }

                if let referenceAudioName = viewModel.referenceAudioName {
                    Text(referenceAudioName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
            }
        }
    }

    private var analyzeCard: some View {
        SectionCard(title: "Analyze") {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    Task {
                        await viewModel.analyze()
                    }
                } label: {
                    HStack {
                        if viewModel.isAnalyzing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isAnalyzing ? "Analyzing..." : "Analyze Pronunciation")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryCapsuleButtonStyle(tint: Color(red: 0.72, green: 0.27, blue: 0.16)))
                .disabled(!viewModel.canAnalyze)

                Text("The backend returns an overall score, the three weakest spans, and plain-language notes.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resultsCard(_ result: AnalyzeResponse) -> some View {
        SectionCard(title: "Result") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(result.overallScore.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                    Text("/ 100")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Worst Segments")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    ForEach(Array(result.worstSegments.enumerated()), id: \.offset) { index, segment in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Segment \(index + 1)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("\(formatTime(segment.startSec)) - \(formatTime(segment.endSec))")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("Score \(segment.segmentScore.formatted(.number.precision(.fractionLength(1))))")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notes")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    ForEach(result.notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color(red: 0.18, green: 0.47, blue: 0.42))
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)

                            Text(note)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Error")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.69, green: 0.16, blue: 0.12))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(red: 0.99, green: 0.94, blue: 0.92),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.96, blue: 0.93),
                Color(red: 0.90, green: 0.93, blue: 0.95),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func formatTime(_ seconds: Double) -> String {
        String(format: "%.2fs", seconds)
    }
}

private struct SectionCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

private struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.16), in: Capsule())
    }
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .padding(14)
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct PrimaryCapsuleButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1.0), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.black.opacity(configuration.isPressed ? 0.08 : 0.05), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    ContentView()
}
