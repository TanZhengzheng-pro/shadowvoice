import Foundation
import Testing

@testable import ShadowVoiceClientCore

@Test func payloadEncodesSnakeCaseKeysAndOptionalReference() throws {
    let payload = AnalyzeRequestPayload(
        targetText: "shadow voice",
        userAudioBase64: "AAA",
        referenceAudioBase64: "BBB"
    )

    let data = try JSONEncoder().encode(payload)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

    #expect(json["target_text"] == "shadow voice")
    #expect(json["user_audio_b64"] == "AAA")
    #expect(json["ref_audio_b64"] == "BBB")
}

@Test func payloadOmitsReferenceWhenNil() throws {
    let payload = AnalyzeRequestPayload(
        targetText: "shadow voice",
        userAudioBase64: "AAA"
    )

    let data = try JSONEncoder().encode(payload)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

    #expect(json["target_text"] == "shadow voice")
    #expect(json["user_audio_b64"] == "AAA")
    #expect(json["ref_audio_b64"] == nil)
}

@Test func responseDecodesSnakeCaseFields() throws {
    let data = """
    {
      "overall_score": 88.4,
      "worst_segments": [
        {
          "start_sec": 0.4,
          "end_sec": 0.9,
          "segment_score": 61.2
        }
      ],
      "notes": [
        "Reference audio provided."
      ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(AnalyzeResponse.self, from: data)

    #expect(response.overallScore == 88.4)
    #expect(response.worstSegments.count == 1)
    #expect(response.worstSegments[0].startSec == 0.4)
    #expect(response.worstSegments[0].endSec == 0.9)
    #expect(response.worstSegments[0].segmentScore == 61.2)
}

@Test func endpointNormalizesAnalyzePath() throws {
    let endpoint = try ShadowVoiceEndpoint(" http://127.0.0.1:8000/ ")

    #expect(endpoint.analyzeURL.absoluteString == "http://127.0.0.1:8000/analyze")
}

@Test func endpointRejectsNonHTTPValues() throws {
    #expect(throws: ShadowVoiceEndpointError.invalidURL("ftp://example.com")) {
        try ShadowVoiceEndpoint("ftp://example.com")
    }
}
