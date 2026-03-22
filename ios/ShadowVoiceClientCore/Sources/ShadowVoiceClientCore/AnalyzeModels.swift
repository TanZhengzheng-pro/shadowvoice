import Foundation

public struct AnalyzeRequestPayload: Encodable, Equatable, Sendable {
    public let targetText: String
    public let userAudioBase64: String
    public let referenceAudioBase64: String?

    public init(
        targetText: String,
        userAudioBase64: String,
        referenceAudioBase64: String? = nil
    ) {
        self.targetText = targetText
        self.userAudioBase64 = userAudioBase64
        self.referenceAudioBase64 = referenceAudioBase64
    }

    enum CodingKeys: String, CodingKey {
        case targetText = "target_text"
        case userAudioBase64 = "user_audio_b64"
        case referenceAudioBase64 = "ref_audio_b64"
    }
}

public struct AnalyzeResponse: Decodable, Equatable, Sendable {
    public let overallScore: Double
    public let worstSegments: [SegmentFeedback]
    public let notes: [String]

    public init(overallScore: Double, worstSegments: [SegmentFeedback], notes: [String]) {
        self.overallScore = overallScore
        self.worstSegments = worstSegments
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case worstSegments = "worst_segments"
        case notes
    }
}

public struct SegmentFeedback: Decodable, Equatable, Sendable, Identifiable {
    public let startSec: Double
    public let endSec: Double
    public let segmentScore: Double

    public init(startSec: Double, endSec: Double, segmentScore: Double) {
        self.startSec = startSec
        self.endSec = endSec
        self.segmentScore = segmentScore
    }

    public var id: String {
        "\(startSec)-\(endSec)-\(segmentScore)"
    }

    enum CodingKeys: String, CodingKey {
        case startSec = "start_sec"
        case endSec = "end_sec"
        case segmentScore = "segment_score"
    }
}

public enum ShadowVoiceEndpointError: LocalizedError, Equatable, Sendable {
    case invalidURL(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let rawValue):
            return "Backend URL is invalid: \(rawValue)"
        }
    }
}

public struct ShadowVoiceEndpoint: Equatable, Sendable {
    public let baseURL: URL

    public init(_ rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            var components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host != nil
        else {
            throw ShadowVoiceEndpointError.invalidURL(rawValue)
        }

        if components.path == "/" {
            components.path = ""
        } else if components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        guard let normalizedURL = components.url else {
            throw ShadowVoiceEndpointError.invalidURL(rawValue)
        }

        self.baseURL = normalizedURL
    }

    public var analyzeURL: URL {
        if baseURL.path.hasSuffix("/analyze") {
            return baseURL
        }
        return baseURL.appendingPathComponent("analyze")
    }
}
