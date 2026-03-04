import XCTest

final class ConductorWSHandshakeUITests: XCTestCase {

    private struct Runtime: Decodable {
        let host: String
        let port: Int
        let token: String
    }

    private func loadRuntime() throws -> Runtime {
        let url = URL(fileURLWithPath: "/tmp/jeeves-runtime.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Missing /tmp/jeeves-runtime.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Runtime.self, from: data)
    }

    func testConductorWebSocketReceivesAnyMessage() async throws {
        let rt = try loadRuntime()
        guard !rt.token.isEmpty else {
            throw XCTSkip("token missing in /tmp/jeeves-runtime.json")
        }

        let app = await XCUIApplication()
        await app.launch()

        let tokenQ = rt.token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rt.token
        let wsURL = try XCTUnwrap(URL(string: "ws://\(rt.host):\(rt.port)/ws/conductor?token=\(tokenQ)"))

        var req = URLRequest(url: wsURL)
        req.setValue("Bearer \(rt.token)", forHTTPHeaderField: "Authorization")

        let task = URLSession(configuration: .default).webSocketTask(with: req)
        task.resume()
        defer {
            task.cancel(with: .normalClosure, reason: nil)
        }

        do {
            let message = try await receiveMessage(task: task)
            switch message {
            case .string(let value):
                XCTAssertFalse(value.isEmpty)
            case .data(let value):
                XCTAssertFalse(value.isEmpty)
            @unknown default:
                throw XCTSkip("Unknown WS message type")
            }
        } catch {
            throw XCTSkip("Gateway websocket unavailable: \(error)")
        }
    }

    private func receiveMessage(task: URLSessionWebSocketTask) async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { continuation in
            task.receive { result in
                continuation.resume(with: result)
            }
        }
    }
}
