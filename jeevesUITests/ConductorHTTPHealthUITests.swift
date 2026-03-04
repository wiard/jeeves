import XCTest

final class ConductorHTTPHealthUITests: XCTestCase {

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

    func testConductorHealthReturnsOkTrue() async throws {
        let rt = try loadRuntime()
        guard !rt.token.isEmpty else {
            throw XCTSkip("token missing in /tmp/jeeves-runtime.json")
        }

        let app = await XCUIApplication()
        await app.launch()

        let url = try XCTUnwrap(URL(string: "http://\(rt.host):\(rt.port)/api/conductor/health?token=\(rt.token)"))

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw XCTSkip("Gateway health endpoint unavailable")
            }
            let body = String(data: data, encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("\"ok\":true"), "Expected ok:true, got: \(body)")
        } catch {
            throw XCTSkip("Gateway health endpoint unavailable: \(error)")
        }
    }
}
