import Foundation

enum CubeOracleAPI {
    static func cards(builder: AuthorizedRequestBuilder) async throws -> [CubeCard] {
        let req = try builder.request(for: RouteContract.Cube.cards)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        if let wrapped = try? JSONDecoder().decode(CubeCardsResponse.self, from: data) {
            return wrapped.cards
        }
        if let direct = try? JSONDecoder().decode([CubeCard].self, from: data) {
            return direct
        }
        throw URLError(.cannotParseResponse)
    }

    static func draw(builder: AuthorizedRequestBuilder, mode: String, topic: String?) async throws -> CubeDrawResponse {
        let body = try JSONEncoder().encode(CubeDrawRequest(mode: mode, topic: topic))
        let req = try builder.request(for: RouteContract.Cube.draw, body: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return try JSONDecoder().decode(CubeDrawResponse.self, from: data)
    }

    static func topics(builder: AuthorizedRequestBuilder) async throws -> [TopicItem] {
        let req = try builder.request(for: RouteContract.Observatory.topics)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        if let wrapped = try? JSONDecoder().decode(CubeTopicsResponse.self, from: data) {
            return wrapped.topics
        }
        if let direct = try? JSONDecoder().decode([TopicItem].self, from: data) {
            return direct
        }
        throw URLError(.cannotParseResponse)
    }

    static func selectTopic(builder: AuthorizedRequestBuilder, topicId: String) async throws -> TopicSelectResponse {
        let body = try JSONEncoder().encode(TopicSelectRequest(topicId: topicId))
        let req = try builder.request(for: RouteContract.Observatory.topicsSelect, body: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return try JSONDecoder().decode(TopicSelectResponse.self, from: data)
    }

    private static func ensureHTTP2xx(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
