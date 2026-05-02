import CoreGraphics
import Foundation
import ImageIO

struct PlankDetector {
    private let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    private let model = "gpt-4.1-mini"

    func detectPlank(in image: CGImage) async throws -> Bool {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "PlankDetector", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing OPENAI_API_KEY"]) 
        }

        let jpegData = try ImageEncoder.jpegData(from: image)
        let base64Image = jpegData.base64EncodedString()

        let payload = ResponsesRequest(
            model: model,
            input: [
                .init(role: "user", content: [
                    .text("Return JSON only: {\"is_plank\": true|false}. Is the person in a proper forearm plank posture?"),
                    .imageURL("data:image/jpeg;base64,\(base64Image)")
                ])
            ]
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw NSError(domain: "PlankDetector", code: 500, userInfo: [NSLocalizedDescriptionKey: text])
        }

        let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        let text = decoded.outputText.lowercased()
        return text.contains("\"is_plank\": true") || text.contains("is_plank:true")
    }
}

private struct ResponsesRequest: Encodable {
    let model: String
    let input: [InputItem]

    struct InputItem: Encodable {
        let role: String
        let content: [InputContent]
    }

    enum InputContent: Encodable {
        case text(String)
        case imageURL(String)

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let value):
                try container.encode("input_text", forKey: .type)
                try container.encode(value, forKey: .text)
            case .imageURL(let value):
                try container.encode("input_image", forKey: .type)
                try container.encode(value, forKey: .imageURL)
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }
    }
}

private struct ResponsesResponse: Decodable {
    let output: [OutputItem]

    var outputText: String {
        output.flatMap { $0.content }.compactMap { $0.text }.joined(separator: " ")
    }

    struct OutputItem: Decodable {
        let content: [OutputContent]
    }

    struct OutputContent: Decodable {
        let text: String?
    }
}

private enum ImageEncoder {
    static func jpegData(from image: CGImage) throws -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.jpeg" as CFString, 1, nil) else {
            throw NSError(domain: "ImageEncoder", code: 1)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "ImageEncoder", code: 2)
        }
        return mutableData as Data
    }
}
