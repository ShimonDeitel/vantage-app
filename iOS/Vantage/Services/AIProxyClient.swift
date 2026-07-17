import Foundation
import UIKit

/// Client for the shared, no-key AI proxy (`apps-ai-proxy`). No secret is embedded —
/// abuse is bounded server-side by the proxy's own per-IP rate limiter.
///
/// The proxy's `/vision` route only forwards the *first* image in the request, so a
/// two-photo critique is two sequential `/vision` calls (one per photo), each asking
/// for a structured JSON set of proportion ratios. `ProportionComparator` then does
/// the actual percentage math client-side. If either photo's JSON fails to parse,
/// Vantage falls back to a single `/text` call that asks the model to phrase the
/// discrepancies as a bullet list from its own two raw descriptions.
final class AIProxyClient {

    enum APIError: LocalizedError {
        case badStatus(Int)
        case emptyResponse
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .badStatus, .emptyResponse:
                return "The critique service is briefly unavailable. Try again in a moment."
            case .network:
                return "Couldn't reach the critique service. Check your connection and try again."
            }
        }
    }

    struct ProportionDescription {
        let measurement: ProportionMeasurement?
        let rawText: String
    }

    static let baseURL = URL(string: "https://apps-ai-proxy.s0533495227.workers.dev")!
    private static let maxImageDimension: CGFloat = 1024
    private static let jpegQuality: CGFloat = 0.6

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: Public

    /// Full critique flow: two `/vision` reads, client-side comparison, and a
    /// `/text` fallback if either read didn't come back as usable structured data.
    func critique(referencePhoto: Data, sketchPhoto: Data) async throws -> [ProportionFeedback] {
        let referenceJPEG = Self.preparedJPEG(from: referencePhoto)
        let sketchJPEG = Self.preparedJPEG(from: sketchPhoto)

        async let referenceTask = describeProportions(imageJPEG: referenceJPEG)
        async let sketchTask = describeProportions(imageJPEG: sketchJPEG)
        let reference = try await referenceTask
        let sketch = try await sketchTask

        if let referenceMeasurement = reference.measurement, let sketchMeasurement = sketch.measurement {
            return ProportionComparator.compare(reference: referenceMeasurement, sketch: sketchMeasurement)
        }

        let bulletText = try await compareByText(referenceText: reference.rawText, sketchText: sketch.rawText)
        return ProportionFeedbackParser.toFeedback(ProportionFeedbackParser.parseBulletLines(bulletText))
    }

    /// Sends one photo to `/vision` and attempts to decode a structured proportion
    /// measurement from the response. Never throws for a malformed model response —
    /// callers get `measurement == nil` and can fall back — but does throw for actual
    /// transport/HTTP failures so the UI can show a real error.
    func describeProportions(imageJPEG jpeg: Data) async throws -> ProportionDescription {
        let content = try await sendVision(systemPrompt: Self.measurementSystemPrompt, userText: Self.measurementUserPrompt, imageJPEG: jpeg)
        let jsonSlice = Self.extractJSONObject(from: content)
        if let data = jsonSlice.data(using: .utf8),
           let response = try? JSONDecoder().decode(ProportionMeasurementResponse.self, from: data) {
            let measurement = ProportionMeasurement(values: response.measurements)
            return ProportionDescription(measurement: measurement.isUsable ? measurement : nil, rawText: content)
        }
        return ProportionDescription(measurement: nil, rawText: content)
    }

    // MARK: Prompts

    private static let measurementUserPrompt = "Estimate this figure's proportions from the photo."

    private static let measurementSystemPrompt = """
    You are a figure-drawing proportion analyst. You are shown one photograph \
    containing a single human figure — either a reference photo or a student's paper \
    sketch of one. Estimate these proportions as fractions of the figure's total \
    height (each a number between 0 and 1): head_to_height, \
    shoulder_width_to_height, hip_width_to_height, arm_length_to_height, \
    leg_length_to_height, torso_to_height, hand_length_to_height.

    Respond with ONLY a JSON object, no markdown fences, no commentary, exactly:
    {"measurements": {"head_to_height": number, "shoulder_width_to_height": number, \
    "hip_width_to_height": number, "arm_length_to_height": number, \
    "leg_length_to_height": number, "torso_to_height": number, \
    "hand_length_to_height": number}}
    """

    private static let comparisonSystemPrompt = """
    You compare two written descriptions of the same figure's proportions: one from \
    a reference photo, one from a student's sketch. List, as short bullet points each \
    starting with "- ", the specific proportion differences a drawing teacher would \
    point out (for example: "- The forearm reads noticeably shorter than the \
    reference"). At most 6 bullets. No preamble, no closing remarks.
    """

    private func compareByText(referenceText: String, sketchText: String) async throws -> String {
        let userText = """
        Reference photo description:
        \(referenceText)

        Sketch photo description:
        \(sketchText)
        """
        return try await sendText(systemPrompt: Self.comparisonSystemPrompt, userText: userText)
    }

    // MARK: Transport

    private func sendVision(systemPrompt: String, userText: String, imageJPEG: Data) async throws -> String {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("vision"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let dataURI = "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())"
        let body = ChatRequest(messages: [
            .system(systemPrompt),
            .userWithImage(text: userText, imageDataURI: dataURI),
        ])
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func sendText(systemPrompt: String, userText: String) async throws -> String {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("text"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body = ChatRequest(messages: [
            .system(systemPrompt),
            .userText(userText),
        ])
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> String {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.badStatus(status)
        }
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw APIError.emptyResponse
        }
        return content
    }

    // MARK: Parsing helpers

    static func extractJSONObject(from content: String) -> String {
        guard let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end else {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(content[start...end])
    }

    // MARK: Image prep

    static func preparedJPEG(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let longEdge = max(image.size.width, image.size.height)
        var output = image
        if longEdge > maxImageDimension, longEdge > 0 {
            let scale = maxImageDimension / longEdge
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            output = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        }
        return output.jpegData(compressionQuality: jpegQuality) ?? data
    }
}

// MARK: - Wire types (matches apps-ai-proxy's OpenAI-compatible chat-completions shape)

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: Content

        static func system(_ text: String) -> Message { Message(role: "system", content: .text(text)) }
        static func userText(_ text: String) -> Message { Message(role: "user", content: .text(text)) }
        static func userWithImage(text: String, imageDataURI: String) -> Message {
            Message(role: "user", content: .parts([.text(text), .image(imageDataURI)]))
        }
    }

    enum Content: Encodable {
        case text(String)
        case parts([ContentPart])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string): try container.encode(string)
            case .parts(let parts): try container.encode(parts)
            }
        }
    }

    struct ContentPart: Encodable {
        let type: String
        var text: String?
        var imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }

        static func text(_ text: String) -> ContentPart { ContentPart(type: "text", text: text, imageURL: nil) }
        static func image(_ dataURI: String) -> ContentPart {
            ContentPart(type: "image_url", text: nil, imageURL: ImageURL(url: dataURI))
        }
    }

    struct ImageURL: Encodable { let url: String }

    let messages: [Message]
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}
