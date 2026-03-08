import Foundation

actor SafeClashClient {
    let baseURL: URL
    let token: String?

    init(baseURL: URL, token: String? = nil) {
        self.baseURL = baseURL
        self.token = token?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func searchIntentions(
        domain: String,
        subdomain: String,
        risk: String,
        constraints: [String: String] = [:]
    ) async throws -> [IntentionProfile] {
        var query = [
            URLQueryItem(name: "domain", value: domain),
            URLQueryItem(name: "subdomain", value: subdomain),
            URLQueryItem(name: "risk", value: risk)
        ]
        for (key, value) in constraints.sorted(by: { $0.key < $1.key }) {
            query.append(URLQueryItem(name: key, value: value))
        }

        let (data, _) = try await request(path: "/api/search", method: "GET", queryItems: query)
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([IntentionProfile].self, from: data) {
            return direct
        }
        if let envelope = try? decoder.decode(SafeClashSearchEnvelope.self, from: data) {
            return envelope.resolved
        }
        throw SafeClashClientError.cannotParseResponse
    }

    func fetchBrowserFeed(
        domain: String? = nil,
        subdomain: String? = nil,
        risk: String? = nil,
        constraints: [String: String] = [:]
    ) async throws -> SafeClashBrowserFeed {
        let candidatePaths = [
            "/api/browser/feed",
            "/api/safeclash/browser/feed",
            "/api/safeclash/browser",
            "/api/browser",
            "/api/intentions/browser"
        ]

        var query: [URLQueryItem] = []
        if let domain, !domain.isEmpty {
            query.append(URLQueryItem(name: "domain", value: domain))
        }
        if let subdomain, !subdomain.isEmpty {
            query.append(URLQueryItem(name: "subdomain", value: subdomain))
        }
        if let risk, !risk.isEmpty {
            query.append(URLQueryItem(name: "risk", value: risk))
        }
        for (key, value) in constraints.sorted(by: { $0.key < $1.key }) {
            query.append(URLQueryItem(name: key, value: value))
        }

        var lastError: Error?
        let decoder = JSONDecoder()

        for path in candidatePaths {
            do {
                let (data, _) = try await request(path: path, method: "GET", queryItems: query)

                if let direct = try? decoder.decode(SafeClashBrowserFeed.self, from: data) {
                    return direct
                }
                if let wrapped = try? decoder.decode(SafeClashBrowserFeedEnvelope.self, from: data),
                   let feed = wrapped.resolved {
                    return feed
                }
                lastError = SafeClashClientError.cannotParseResponse
            } catch SafeClashClientError.httpStatus(let status) where status == 404 {
                continue
            } catch {
                lastError = error
            }
        }

        throw lastError ?? SafeClashClientError.notFound
    }

    func getConfiguration(configId: String) async throws -> AIConfigurationAtom {
        let escaped = configId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? configId
        let candidatePaths = [
            "/api/configurations/\(escaped)",
            "/api/configuration/\(escaped)",
            "/api/search/configurations/\(escaped)",
            "/api/search/config/\(escaped)"
        ]

        var lastError: Error?
        for path in candidatePaths {
            do {
                let (data, _) = try await request(path: path, method: "GET")
                let decoder = JSONDecoder()
                if let direct = try? decoder.decode(AIConfigurationAtom.self, from: data) {
                    return direct
                }
                if let envelope = try? decoder.decode(SafeClashConfigurationEnvelope.self, from: data),
                   let config = envelope.resolved {
                    return config
                }
                lastError = SafeClashClientError.cannotParseResponse
            } catch {
                lastError = error
            }
        }

        throw lastError ?? SafeClashClientError.notFound
    }

    func fetchEmergingIntentions(
        domain: String? = nil,
        subdomain: String? = nil,
        risk: String? = nil,
        constraints: [String: String] = [:]
    ) async throws -> [EmergingIntentionProfile] {
        let candidatePaths = [
            "/api/intentions/emerging",
            "/api/intention-candidates",
            "/api/search/intention-candidates",
            "/api/search/emerging-intentions"
        ]
        var query: [URLQueryItem] = []
        if let domain, !domain.isEmpty {
            query.append(URLQueryItem(name: "domain", value: domain))
        }
        if let subdomain, !subdomain.isEmpty {
            query.append(URLQueryItem(name: "subdomain", value: subdomain))
        }
        if let risk, !risk.isEmpty {
            query.append(URLQueryItem(name: "risk", value: risk))
        }
        for (key, value) in constraints.sorted(by: { $0.key < $1.key }) {
            query.append(URLQueryItem(name: key, value: value))
        }

        for path in candidatePaths {
            do {
                let (data, _) = try await request(path: path, method: "GET", queryItems: query)
                let decoder = JSONDecoder()

                if let direct = try? decoder.decode([EmergingIntentionProfile].self, from: data) {
                    return direct
                }
                if let envelope = try? decoder.decode(EmergingIntentionsEnvelope.self, from: data) {
                    return envelope.resolved
                }
            } catch SafeClashClientError.httpStatus(let status) where status == 404 {
                continue
            } catch {
                throw error
            }
        }
        return []
    }

    private func request(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw SafeClashClientError.httpStatus(http.statusCode)
        }
        return (data, http)
    }

    private func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
}

enum SafeClashClientError: Error {
    case httpStatus(Int)
    case cannotParseResponse
    case notFound
}
