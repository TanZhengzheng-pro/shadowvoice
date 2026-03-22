import Foundation

import ShadowVoiceClientCore

enum ShadowVoiceAPIError: LocalizedError {
    case invalidHTTPResponse
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "The backend returned an invalid HTTP response."
        case .server(let statusCode, let message):
            return "Backend error \(statusCode): \(message)"
        }
    }
}

struct ShadowVoiceAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func analyze(
        baseURLString: String,
        targetText: String,
        userAudioData: Data,
        referenceAudioData: Data?
    ) async throws -> AnalyzeResponse {
        let endpoint = try ShadowVoiceEndpoint(baseURLString)
        let payload = AnalyzeRequestPayload(
            targetText: targetText,
            userAudioBase64: userAudioData.base64EncodedString(),
            referenceAudioBase64: referenceAudioData?.base64EncodedString()
        )

        var request = URLRequest(url: endpoint.analyzeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShadowVoiceAPIError.invalidHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ShadowVoiceAPIError.server(
                statusCode: httpResponse.statusCode,
                message: decodeServerMessage(from: data)
            )
        }

        return try JSONDecoder().decode(AnalyzeResponse.self, from: data)
    }

    private func decodeServerMessage(from data: Data) -> String {
        if
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = object["detail"] as? String
        {
            return detail
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        return "Unknown error"
    }
}
