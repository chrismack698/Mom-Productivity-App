import Foundation

// MARK: - URL Session Protocol (testability)
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
extension URLSession: URLSessionProtocol {}

// MARK: - Internal API types
private struct APIMessage: Encodable {
    let role: String
    let content: String
}

private struct APIRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [APIMessage]
    enum CodingKeys: String, CodingKey {
        case model, messages, system
        case maxTokens = "max_tokens"
    }
}

private struct APIResponseContent: Decodable {
    let text: String
}

private struct APIResponse: Decodable {
    let content: [APIResponseContent]
}

// MARK: - Errors
enum ClaudeError: Error {
    case httpError(Int)
    case parseError
}

// MARK: - Implementation
final class ClaudeServiceImpl: ClaudeService {
    private let apiKey: String
    private let urlSession: any URLSessionProtocol
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    init(apiKey: String, urlSession: any URLSessionProtocol = URLSession.shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    func triage(captures: [CaptureItem], userContext: String) async throws -> [TriageResult] {
        let captureText = captures.enumerated().map { i, c in
            "[\(i + 1)] \(c.rawContent)"
        }.joined(separator: "\n")

        let systemPrompt = """
        You are a voice-first family life admin assistant. Analyze the captured items and return ONLY valid JSON.

        User context and preferences:
        \(userContext.isEmpty ? "No preferences yet — this is a new user." : userContext)

        Return this exact JSON format and nothing else:
        {
          "tasks": [
            {
              "title": "clear action title",
              "firstStep": "specific 10-minute first step",
              "timeHorizon": "today" | "thisWeek" | "someday",
              "deadline": "ISO8601 date string or null",
              "category": "appointment" | "errand" | "admin" | "personal",
              "scheduledNotification": {
                "title": "reminder title",
                "body": "first step reminder",
                "triggerDate": "ISO8601 date string"
              } | null
            }
          ]
        }

        Rules:
        - Break vague captures into concrete first steps (~10 min each)
        - Keep output practical, calm, and boring
        - Prefer one clear next action over a long plan
        - Only set deadline if explicitly mentioned
        - Do not invent calendar times or commitments
        - Only include scheduledNotification if there's a real deadline or urgent time sensitivity
        - One capture may produce multiple tasks only when the user clearly mentioned multiple responsibilities
        - timeHorizon must be exactly: today, thisWeek, or someday
        """

        let request = APIRequest(
            model: model,
            maxTokens: 1024,
            system: systemPrompt,
            messages: [APIMessage(role: "user", content: "Process these captured items:\n\(captureText)")]
        )

        let responseText = try await send(request)
        let json = extractJSON(from: responseText)

        // Intermediate type that decodes the API's camelCase timeHorizon values
        // (e.g. "today", "thisWeek", "someday") and maps them to TimeHorizon
        struct RawTask: Decodable {
            let title: String
            let firstStep: String
            let timeHorizon: String
            let deadline: Date?
            let category: String
            let scheduledNotification: TriageResult.ScheduledNotification?
        }

        struct RawTriageResponse: Decodable {
            let tasks: [RawTask]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = json.data(using: .utf8),
              let parsed = try? decoder.decode(RawTriageResponse.self, from: data) else {
            throw ClaudeError.parseError
        }

        return try parsed.tasks.map { raw in
            let horizon: TimeHorizon = switch raw.timeHorizon {
            case "today": .today
            case "thisWeek": .thisWeek
            case "someday": .someday
            default: throw ClaudeError.parseError
            }
            return TriageResult(
                title: raw.title,
                firstStep: raw.firstStep,
                timeHorizon: horizon,
                deadline: raw.deadline,
                category: raw.category,
                scheduledNotification: raw.scheduledNotification
            )
        }
    }

    func chat(messages: [ChatMessage], taskContext: ActionItem, userContext: String) async throws -> String {
        let systemPrompt = """
        You are a helpful family life admin assistant.

        Task context: \(taskContext.title)
        First step: \(taskContext.firstStep)
        Category: \(taskContext.category)

        User preferences:
        \(userContext.isEmpty ? "No preferences yet." : userContext)

        Keep responses brief, practical, and calm. No jargon. Focus on reducing overwhelm.
        """

        // Context compression: only last 10 messages
        let recent = messages
            .sorted(by: { $0.createdAt < $1.createdAt })
            .suffix(10)

        let apiMessages = recent.map {
            APIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content)
        }

        guard apiMessages.last?.role == "user" else {
            throw ClaudeError.parseError
        }

        let request = APIRequest(
            model: model,
            maxTokens: 512,
            system: systemPrompt,
            messages: Array(apiMessages)
        )

        return try await send(request)
    }

    // MARK: - Private

    private func send(_ body: APIRequest) async throws -> String {
        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClaudeError.httpError(code)
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    private func extractJSON(from text: String) -> String {
        // Claude sometimes wraps JSON in markdown code blocks — strip them
        if let start = text.range(of: "{"),
           let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return text
    }
}
