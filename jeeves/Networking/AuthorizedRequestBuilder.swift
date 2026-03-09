import Foundation

/// The single canonical builder for all authorized HTTP requests to a gateway endpoint.
/// Thread-safe (Sendable) — can be passed to actors and background tasks.
struct AuthorizedRequestBuilder: Sendable {
    let baseURL: URL
    let token: String

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    init(host: String, port: Int, token: String) {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        self.baseURL = components.url ?? URL(string: "http://localhost:19001")!
        self.token = token
    }

    /// Build a URLRequest for the given route, applying:
    /// 1. Bearer token in Authorization header
    /// 2. Token as query parameter (for gateway compatibility)
    /// 3. Content-Type for POST bodies
    /// 4. Accept: application/json
    func request(
        for route: Route,
        body: Data? = nil,
        additionalQuery: [URLQueryItem] = [],
        timeoutInterval: TimeInterval? = nil
    ) throws -> URLRequest {
        try request(
            path: route.path,
            method: route.method,
            body: body,
            queryItems: route.query + additionalQuery,
            includeTokenQuery: true,
            timeoutInterval: timeoutInterval
        )
    }

    /// Build a request from a raw path string.
    /// Used by SafeClash fallback paths and other dynamic routes.
    func request(
        path: String,
        method: String,
        body: Data? = nil,
        queryItems: [URLQueryItem] = [],
        includeTokenQuery: Bool = true,
        timeoutInterval: TimeInterval? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = path

        var allQuery = queryItems
        if includeTokenQuery, !token.isEmpty {
            allQuery.insert(URLQueryItem(name: "token", value: token), at: 0)
        }
        components.queryItems = allQuery.isEmpty ? nil : allQuery

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let timeout = timeoutInterval {
            req.timeoutInterval = timeout
        }

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }

        return req
    }
}
