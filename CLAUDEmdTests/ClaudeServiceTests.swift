import Testing
@testable import MyApp
import Foundation

struct ClaudeServiceTests {
    @Test func triageRequestParsesValidResponse() async throws {
        let session = MockURLSession()
        let mockJSON = """
        {
          "content": [{
            "text": "{\\"tasks\\":[{\\"title\\":\\"Call doctor\\",\\"firstStep\\":\\"Find number\\",\\"timeHorizon\\":\\"today\\",\\"deadline\\":null,\\"category\\":\\"appointment\\",\\"scheduledNotification\\":null}]}"
          }]
        }
        """
        session.mockData = mockJSON.data(using: .utf8)!
        session.mockStatusCode = 200

        let service = ClaudeServiceImpl(apiKey: "test-key", urlSession: session)
        let capture = CaptureItem(rawContent: "reschedule pediatrician")
        let results = try await service.triage(captures: [capture], userContext: "")
        #expect(results.count == 1)
        #expect(results[0].title == "Call doctor")
        #expect(results[0].timeHorizon == .today)
    }

    @Test func chatRequestReturnsAssistantText() async throws {
        let session = MockURLSession()
        let mockJSON = """
        {
          "content": [{"text": "Sure, here are the steps: 1. Call the office..."}]
        }
        """
        session.mockData = mockJSON.data(using: .utf8)!
        session.mockStatusCode = 200

        let service = ClaudeServiceImpl(apiKey: "test-key", urlSession: session)
        let capture = CaptureItem(rawContent: "test")
        let item = ActionItem(title: "Test", firstStep: "Do it", timeHorizon: .today, category: "errand", captureItem: capture)
        let result = try await service.chat(messages: [], taskContext: item, userContext: "")
        #expect(result.contains("Call the office"))
    }

    @Test func httpErrorThrows() async throws {
        let session = MockURLSession()
        session.mockData = Data()
        session.mockStatusCode = 429

        let service = ClaudeServiceImpl(apiKey: "test-key", urlSession: session)
        let capture = CaptureItem(rawContent: "test")
        await #expect(throws: ClaudeError.self) {
            try await service.triage(captures: [capture], userContext: "")
        }
    }
}

// MARK: - Mock
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var mockData: Data = Data()
    var mockStatusCode: Int = 200

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: mockStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (mockData, response)
    }
}
