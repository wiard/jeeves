import Foundation

/// Lightweight health validation that probes required routes per feature area.
enum GatewayHealthValidator {

    enum Area: String, CaseIterable, Sendable {
        case core
        case chat
        case browser
        case observatory
        case deployments
    }

    struct HealthResult: Sendable {
        let area: Area
        let available: Bool
        let latencyMs: Int?
        let failedRoutes: [Route]
    }

    /// Probe a single feature area by hitting its required routes.
    static func validate(area: Area, builder: AuthorizedRequestBuilder) async -> HealthResult {
        let routes = routeSet(for: area)
        let start = ContinuousClock.now
        var failed: [Route] = []

        for route in routes {
            do {
                let req = try builder.request(for: route, timeoutInterval: 5)
                let (_, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    failed.append(route)
                }
            } catch {
                failed.append(route)
            }
        }

        let elapsed = ContinuousClock.now - start
        let seconds: Double = Double(elapsed.components.seconds)
        let attos: Double = Double(elapsed.components.attoseconds)
        let ms = Int(seconds * 1000 + attos / 1_000_000_000_000_000)

        return HealthResult(
            area: area,
            available: failed.isEmpty,
            latencyMs: ms,
            failedRoutes: failed
        )
    }

    /// Probe all feature areas in parallel.
    static func validateAll(builder: AuthorizedRequestBuilder) async -> [HealthResult] {
        await withTaskGroup(of: HealthResult.self) { group in
            for area in Area.allCases {
                group.addTask {
                    await validate(area: area, builder: builder)
                }
            }
            var results: [HealthResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private static func routeSet(for area: Area) -> [Route] {
        switch area {
        case .core:        return RouteContract.HealthRouteSet.core
        case .chat:        return RouteContract.HealthRouteSet.chat
        case .browser:     return RouteContract.HealthRouteSet.browser
        case .observatory: return RouteContract.HealthRouteSet.observatory
        case .deployments: return RouteContract.HealthRouteSet.deployments
        }
    }
}
