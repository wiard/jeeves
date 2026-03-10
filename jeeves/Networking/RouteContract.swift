import Foundation

/// A typed description of an HTTP route.
struct Route: Hashable, Sendable {
    let method: String
    let path: String
    let query: [URLQueryItem]

    static func get(_ path: String, query: [URLQueryItem] = []) -> Route {
        Route(method: "GET", path: path, query: query)
    }

    static func post(_ path: String, query: [URLQueryItem] = []) -> Route {
        Route(method: "POST", path: path, query: query)
    }
}

/// Every HTTP route the Jeeves app calls, typed and organized by domain.
enum RouteContract {

    // MARK: - Health

    static let health = Route.get("/api/health")

    // MARK: - Conductor

    enum Conductor {
        static let health         = Route.get("/api/conductor/health")
        static let state          = Route.get("/api/conductor/state")
        static let intent         = Route.post("/api/conductor/intent")
        static let audit          = Route.get("/api/conductor/audit")
        static let killActivate   = Route.post("/api/conductor/kill/activate")
        static let killDeactivate = Route.post("/api/conductor/kill/deactivate")
    }

    // MARK: - Briefing

    enum Briefing {
        static let daily = Route.get("/api/briefing/daily")
    }

    // MARK: - Fabric

    enum Fabric {
        static let clock     = Route.get("/api/fabric/clock")
        static let emergence = Route.get("/api/fabric/emergence")
        static let state     = Route.get("/api/fabric/state")
    }

    // MARK: - Knowledge

    enum Knowledge {
        static let status     = Route.get("/api/knowledge/status")
        static let emergence  = Route.get("/api/knowledge/emergence")
        static let residue    = Route.get("/api/knowledge/residue")
        static let collisions = Route.get("/api/knowledge/collisions")
        static func objectsRecent(limit: Int) -> Route {
            .get("/api/knowledge/objects/recent", query: [URLQueryItem(name: "limit", value: "\(limit)")])
        }
        static func objectGraph(objectId: String) -> Route {
            .get("/api/knowledge/objects/\(objectId)/graph")
        }
    }

    // MARK: - Observatory

    enum Observatory {
        static let alerts = Route.get("/api/observatory/alerts")
        static func stream(limit: Int) -> Route {
            .get("/api/observatory/stream", query: [URLQueryItem(name: "limit", value: "\(limit)")])
        }
        static let topics       = Route.get("/api/observatory/topics")
        static let topicsSelect = Route.post("/api/observatory/topics/select")
    }

    // MARK: - Lobby

    enum Lobby {
        static let challenges = Route.get("/api/lobby/challenges")
    }

    // MARK: - Signals

    enum Signals {
        static let state = Route.get("/api/signals/state")
    }

    // MARK: - Radar

    enum Radar {
        static let status = Route.get("/api/radar/status")
        static func activations(limit: Int) -> Route {
            .get("/api/radar/activations", query: [URLQueryItem(name: "limit", value: "\(limit)")])
        }
        static let collisions  = Route.get("/api/radar/collisions")
        static let emergence   = Route.get("/api/radar/emergence")
        static let clusters    = Route.get("/api/radar/clusters")
        static let sources     = Route.get("/api/radar/sources")
        static let gravity     = Route.get("/api/radar/gravity")
        static let discoveries = Route.get("/api/radar/discoveries")
    }

    // MARK: - Cube

    enum Cube {
        static let cards = Route.get("/api/cube/cards")
        static let draw  = Route.post("/api/cube/draw")
    }

    // MARK: - Agents

    enum Agents {
        static let proposals       = Route.get("/api/agents/proposals")
        static let proposalsRanked = Route.get("/api/agents/proposals/ranked")
        static let proposalsDecide = Route.post("/api/agents/proposals/decide")
        static let propose         = Route.post("/api/agents/propose")
        static func proposalsDecided(limit: Int) -> Route {
            .get("/api/agents/proposals/decided", query: [URLQueryItem(name: "limit", value: "\(limit)")])
        }
    }

    // MARK: - Extensions

    enum Extensions {
        static let list          = Route.get("/api/extensions")
        static let incomingTools = Route.get("/api/extensions/incoming-tools")
        static func detail(id: String) -> Route  { .get("/api/extensions/\(id)") }
        static func graph(id: String) -> Route   { .get("/api/extensions/\(id)/graph") }
        static func approve(id: String) -> Route  { .post("/api/extensions/\(id)/approve") }
        static func deny(id: String) -> Route     { .post("/api/extensions/\(id)/deny") }
        static func load(id: String) -> Route     { .post("/api/extensions/\(id)/load") }
    }

    // MARK: - Other

    static let message              = Route.post("/api/message")
    static let actions              = Route.get("/api/actions")
    static let search               = Route.get("/api/search")
    static let configurationsDeploy = Route.post("/api/configurations/deploy")
    static let openclawSkillsSummary = Route.get("/api/openclaw/skills/summary")

    // MARK: - Browser (SafeClash, with fallback paths)

    enum Browser {
        static let feedCandidates: [String] = [
            "/api/browser/feed",
            "/api/safeclash/browser/feed",
            "/api/safeclash/browser",
            "/api/browser",
            "/api/intentions/browser"
        ]
        static let emergingCandidates: [String] = [
            "/api/intentions/emerging",
            "/api/intention-candidates",
            "/api/search/intention-candidates",
            "/api/search/emerging-intentions"
        ]
        static func configurationCandidates(configId: String) -> [String] {
            let escaped = configId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? configId
            return [
                "/api/configurations/\(escaped)",
                "/api/configuration/\(escaped)",
                "/api/search/configurations/\(escaped)",
                "/api/search/config/\(escaped)"
            ]
        }
    }

    // MARK: - Health Validation Route Sets

    enum HealthRouteSet {
        static let core: [Route]        = [Conductor.health]
        static let chat: [Route]        = [RouteContract.message]
        static let browser: [Route]     = [Route.get("/api/browser/feed"), RouteContract.search]
        static let observatory: [Route] = [Conductor.state, Observatory.alerts, Fabric.clock, Signals.state, Radar.status]
        static let deployments: [Route] = [RouteContract.configurationsDeploy, Agents.proposals]
    }
}
