import Foundation

enum CubeOracleAPI {
    static func cards(host: String, port: Int, token: String) async throws -> [CubeCard] {
        let data = try await get(host: host, port: port, token: token, path: "/api/cube/cards")
        if let wrapped = try? JSONDecoder().decode(CubeCardsResponse.self, from: data) {
            return wrapped.cards
        }
        if let direct = try? JSONDecoder().decode([CubeCard].self, from: data) {
            return direct
        }
        throw URLError(.cannotParseResponse)
    }

    static func draw(host: String, port: Int, token: String, mode: String, topic: String?) async throws -> CubeDrawResponse {
        let body = try JSONEncoder().encode(CubeDrawRequest(mode: mode, topic: topic))
        let data = try await post(host: host, port: port, token: token, path: "/api/cube/draw", body: body)
        return try JSONDecoder().decode(CubeDrawResponse.self, from: data)
    }

    static func topics(host: String, port: Int, token: String) async throws -> [TopicItem] {
        let data = try await get(host: host, port: port, token: token, path: "/api/observatory/topics")
        if let wrapped = try? JSONDecoder().decode(CubeTopicsResponse.self, from: data) {
            return wrapped.topics
        }
        if let direct = try? JSONDecoder().decode([TopicItem].self, from: data) {
            return direct
        }
        throw URLError(.cannotParseResponse)
    }

    static func selectTopic(host: String, port: Int, token: String, topicId: String) async throws -> TopicSelectResponse {
        let body = try JSONEncoder().encode(TopicSelectRequest(topicId: topicId))
        let data = try await post(host: host, port: port, token: token, path: "/api/observatory/topics/select", body: body)
        return try JSONDecoder().decode(TopicSelectResponse.self, from: data)
    }

    private static func get(host: String, port: Int, token: String, path: String) async throws -> Data {
        let url = try endpointURL(host: host, port: port, token: token, path: path)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensure2xx(response)
        return data
    }

    private static func post(host: String, port: Int, token: String, path: String, body: Data) async throws -> Data {
        let url = try endpointURL(host: host, port: port, token: token, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensure2xx(response)
        return data
    }

    private static func endpointURL(host: String, port: Int, token: String, path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private static func ensure2xx(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
