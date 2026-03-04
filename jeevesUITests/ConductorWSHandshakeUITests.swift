import XCTest

final class ConductorWSHandshakeUITests: XCTestCase {

    private struct Runtime: Decodable {
        let host: String
        let port: Int
        let token: String
    }

    private func loadRuntime() throws -> Runtime {
        let url = URL(fileURLWithPath: "/tmp/jeeves-runtime.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Runtime.self, from: data)
    }

    func testConductorWebSocketReceivesAnyMessage() throws {
        let rt = try loadRuntime()
        XCTAssertFalse(rt.token.isEmpty, "token missing in /tmp/jeeves-runtime.json")

        let app = XCUIApplication()
        app.launch()

        let tokenQ = rt.token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rt.token
        let wsURL = try XCTUnwrap(URL(string: "ws://\(rt.host):\(rt.port)/ws/conductor?token=\(tokenQ)"))

        var req = URLRequest(url: wsURL)
        req.setValue("Bearer \(rt.token)", forHTTPHeaderField: "Authorization")

        let task = URLSession(configuration: .default).webSocketTask(with: req)
        task.resume()

        let exp = expectation(description: "ws-receive")
        task.receive { result in
            switch result {
            case .failure(let err):
                XCTFail("WS receive failed: \(err)")
            case .success(let msg):
                switch msg {
                case .string(let s):
                    XCTAssertFalse(s.isEmpty)
                case .data(let d):
                    XCTAssertTrue(!d.isEmpty)
                @unknown default:
                    XCTFail("Unknown WS message")
                }
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 8.0)
        task.cancel(with: .normalClosure, reason: nil)
    }
}
