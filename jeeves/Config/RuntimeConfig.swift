import Foundation

@MainActor
final class RuntimeConfig {

    static let shared = RuntimeConfig()

    /// true => app werkt tegen MockGateway
    let useMock: Bool

    /// Overrides (nil = geen override)
    let host: String?
    let port: Int?
    let token: String?

    private init() {
        let env = ProcessInfo.processInfo.environment

        // 1) Environment overrides (optionals)
        let envMock  = (env["MOCK"] == "1")
        let envHost  = Self.nilIfBlank(env["HOST"])
        let envPort  = Self.nilIfZeroOrInvalid(env["PORT"])
        let envToken = Self.nilIfBlank(env["TOKEN"])

        // 2) Runtime file fallback
        let file = Self.loadRuntimeFile()

        // precedence: ENV > file > nil
        self.useMock = envMock
        self.host  = envHost  ?? file?.host
        self.port  = envPort  ?? file?.port
        self.token = envToken ?? file?.token

        Self.debugPrintConfig(useMock: useMock, host: host, port: port, token: token)
    }

    // MARK: - Runtime file support

    private struct RuntimeFile: Decodable {
        let host: String
        let port: Int
        let token: String
    }

    /// Leest `Documents/jeeves-runtime.json` in de app-sandbox.
    /// (Let op: op simulator/macOS krijg je die file in Documents via simctl / Files app.)
    private static func loadRuntimeFile() -> RuntimeFile? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = docs.appendingPathComponent("jeeves-runtime.json")

        guard fm.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(RuntimeFile.self, from: data)

            // normalize: lege strings / 0 => nil
            let host = decoded.host.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty, decoded.port > 0 else { return nil }
            let token = decoded.token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { return nil }

            return RuntimeFile(host: host, port: decoded.port, token: token)
        } catch {
            print("⚠️ RuntimeConfig: failed to read runtime file:", error)
            return nil
        }
    }

    // MARK: - Helpers

    private static func nilIfBlank(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func nilIfZeroOrInvalid(_ s: String?) -> Int? {
        guard let s else { return nil }
        guard let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)), n > 0 else { return nil }
        return n
    }

    private static func debugPrintConfig(useMock: Bool,
                                         host: String?,
                                         port: Int?,
                                         token: String?) {
        let tokenPreview = token.map { String($0.prefix(16)) + "…" } ?? "nil"
        print("""
        ─────────────────────────────
        RuntimeConfig
        useMock: \(useMock)
        host: \(host ?? "nil")
        port: \(port.map(String.init) ?? "nil")
        token: \(tokenPreview)
        ─────────────────────────────
        """)
    }
}
