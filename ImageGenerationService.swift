//
//  ImageGenerationService.swift
//  CalorieAI
//
//  Protocol + two swappable providers for turning a food description into a
//  studio-styled photo. `ImageGenerationService` is the entry point views
//  and `AgentTools` call — it owns caching and provider selection so nobody
//  else needs to know which model is behind it.
//

import Foundation

enum ImageGenerationError: Error, LocalizedError {
    case missingAPIKey(ImageProviderKind)
    case badResponse(String)
    case emptyImageData

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let kind):
            "No API key saved for \(kind.label). Add one in Settings to generate food photos."
        case .badResponse(let detail):
            "Image generation failed: \(detail)"
        case .emptyImageData:
            "The image provider returned no image data."
        }
    }
}

protocol ImageGenerationProviding: Sendable {
    /// Returns raw image bytes (PNG or JPEG) for the given fully-assembled
    /// prompt (already run through `ImagePromptTemplate`).
    func generateImageData(prompt: String) async throws -> Data
}

/// Orchestrates: cache lookup → provider call → cache write. Every call site
/// (the agent's `log_food_entry` tool, a manual "regenerate photo" action)
/// goes through here rather than talking to a provider directly.
actor ImageGenerationService {
    static let shared = ImageGenerationService()

    private var inFlight: [String: Task<String, Error>] = [:]

    private func provider(for kind: ImageProviderKind) throws -> ImageGenerationProviding {
        switch kind {
        case .openAI:
            guard let key = KeychainStore.apiKey(for: .openAI) else {
                throw ImageGenerationError.missingAPIKey(.openAI)
            }
            return OpenAIImageProvider(apiKey: key)
        case .gemini:
            guard let key = KeychainStore.apiKey(for: .gemini) else {
                throw ImageGenerationError.missingAPIKey(.gemini)
            }
            return GeminiImageProvider(apiKey: key)
        }
    }

    /// Returns a local file path (suitable for `FoodEntry.localImagePath`).
    /// Coalesces concurrent requests for the same signature so logging the
    /// same food twice in a row doesn't fire two generations.
    func image(
        signature: String,
        foodDescription: String,
        provider providerKind: ImageProviderKind
    ) async throws -> String {
        if let existing = ImageCache.existingPath(for: signature) {
            return existing
        }

        if let existingTask = inFlight[signature] {
            return try await existingTask.value
        }

        let task = Task<String, Error> {
            defer { inFlight[signature] = nil }
            let provider = try provider(for: providerKind)
            let prompt = ImagePromptTemplate.prompt(for: foodDescription)
            let data = try await provider.generateImageData(prompt: prompt)
            guard !data.isEmpty else { throw ImageGenerationError.emptyImageData }
            return try ImageCache.store(data, for: signature)
        }
        inFlight[signature] = task
        return try await task.value
    }
}

// MARK: - OpenAI (gpt-image-1)

struct OpenAIImageProvider: ImageGenerationProviding {
    let apiKey: String
    var model: String = "gpt-image-1"
    var size: String = "1024x1024"
    var quality: String = "medium"

    private struct RequestBody: Encodable {
        let model: String
        let prompt: String
        let size: String
        let quality: String
        let n: Int
    }
    private struct ResponseBody: Decodable {
        struct Item: Decodable { let b64_json: String? }
        let data: [Item]
    }

    func generateImageData(prompt: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(model: model, prompt: prompt, size: size, quality: quality, n: 1)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageGenerationError.badResponse("OpenAI \((response as? HTTPURLResponse)?.statusCode ?? -1): \(body.prefix(300))")
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let b64 = decoded.data.first?.b64_json, let imageData = Data(base64Encoded: b64) else {
            throw ImageGenerationError.emptyImageData
        }
        return imageData
    }
}

// MARK: - Gemini (2.5 Flash Image)

struct GeminiImageProvider: ImageGenerationProviding {
    let apiKey: String
    var model: String = "gemini-2.5-flash-image"

    private struct RequestBody: Encodable {
        struct Part: Encodable { let text: String }
        struct Content: Encodable { let parts: [Part] }
        let contents: [Content]
    }
    private struct ResponseBody: Decodable {
        struct InlineData: Decodable { let mimeType: String?; let data: String? }
        struct Part: Decodable { let inlineData: InlineData? }
        struct Content: Decodable { let parts: [Part]? }
        struct Candidate: Decodable { let content: Content? }
        let candidates: [Candidate]?
    }

    func generateImageData(prompt: String) async throws -> Data {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(contents: [.init(parts: [.init(text: prompt)])])
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageGenerationError.badResponse("Gemini \((response as? HTTPURLResponse)?.statusCode ?? -1): \(body.prefix(300))")
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard
            let parts = decoded.candidates?.first?.content?.parts,
            let b64 = parts.compactMap({ $0.inlineData?.data }).first,
            let imageData = Data(base64Encoded: b64)
        else {
            throw ImageGenerationError.emptyImageData
        }
        return imageData
    }
}
