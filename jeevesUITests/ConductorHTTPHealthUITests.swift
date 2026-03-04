import XCTest

final class ConductorHTTPHealthUITests: XCTestCase {

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

    func testConductorHealthReturnsOkTrue() throws {
        let rt = try loadRuntime()
        XCTAssertFalse(rt.token.isEmpty, "token missing in /tmp/jeeves-runtime.json")

        let app = XCUIApplication()
        app.launch()

        let url = try XCTUnwrap(URL(string: "http://\(rt.host):\(rt.port)/api/conductor/health?token=\(rt.token)"))

        let exp = expectation(description: "health")
        URLSession.shared.dataTask(with: url) { data, _, err in
            XCTAssertNil(err)
            let body = String(data: data ?? Data(), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("\"ok\":true"), "Expected ok:true, got: \(body)")
            exp.fulfill()
        }.resume()

        wait(for: [exp], timeout: 5.0)
    }
}
