import Foundation

struct CubePosition: Hashable, Codable, Sendable {
    let x: Int
    let y: Int
    let z: Int

    init(x: Int, y: Int, z: Int) {
        self.x = max(0, min(2, x))
        self.y = max(0, min(2, y))
        self.z = max(0, min(2, z))
    }

    var id: String { "\(x)-\(y)-\(z)" }

    static let origin = CubePosition(x: 0, y: 0, z: 0)
}

struct ClashdCell: Identifiable, Sendable {
    let position: CubePosition
    let residue: Double
    let highlightedClusterId: String?
    let routeArrows: [String]

    var id: String { position.id }

    var residueClamped: Double {
        max(0, min(1, residue))
    }
}

struct ClashdRoute: Identifiable, Sendable {
    let id: String
    let from: CubePosition
    let to: CubePosition
    let strength: Double
}

struct KnowledgeCollisionCluster: Identifiable, Sendable {
    let clusterId: String
    let sourceTypes: [String]
    let densityScore: Double
    let cubePosition: CubePosition
    let summary: String
    let isEmergence: Bool

    var id: String { clusterId }
}

struct LoopMetrics: Sendable {
    let lastCycleDuration: TimeInterval
    let averageCycleDuration: TimeInterval
    let signalsToday: Int
    let challengesToday: Int
    let proposalsToday: Int
    let executedActions: Int

    static let empty = LoopMetrics(
        lastCycleDuration: 0,
        averageCycleDuration: 0,
        signalsToday: 0,
        challengesToday: 0,
        proposalsToday: 0,
        executedActions: 0
    )
}

enum JeevesDecisionKind: String, Sendable {
    case autoApproved = "auto-approved"
    case autoDenied = "auto-denied"
    case escalated = "escalated"
}

struct JeevesDecisionEvent: Identifiable, Sendable {
    let id: String
    let kind: JeevesDecisionKind
    let title: String
    let timestamp: Date

    var isAnomaly: Bool {
        kind == .escalated
    }
}

struct EmergenceAlert: Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let clusterId: String
    let timestamp: Date

    static func fromCluster(_ cluster: KnowledgeCollisionCluster, now: Date = Date()) -> EmergenceAlert {
        EmergenceAlert(
            id: "alert-\(cluster.clusterId)",
            title: "Unexpected connection detected",
            summary: cluster.summary,
            clusterId: cluster.clusterId,
            timestamp: now
        )
    }
}

struct ClashdCubeField: Sendable {
    let cells: [ClashdCell]
    let activeRoutes: [ClashdRoute]
    let clusters: [KnowledgeCollisionCluster]

    static let empty = ClashdCubeField(cells: [], activeRoutes: [], clusters: [])
}

struct ObservatorySnapshot: Sendable {
    let loop: LoopMetrics
    let field: ClashdCubeField
    let collisions: [KnowledgeCollisionCluster]
    let decisions: [JeevesDecisionEvent]
    let updatedAt: Date

    static let empty = ObservatorySnapshot(
        loop: .empty,
        field: .empty,
        collisions: [],
        decisions: [],
        updatedAt: Date()
    )

    static func demo(tick: Int, now: Date = Date()) -> ObservatorySnapshot {
        let cells = demoCells(tick: tick)
        let routes = demoRoutes(tick: tick)
        let clusters = demoClusters(tick: tick)
        let decisions = demoDecisions(tick: tick, now: now)

        let lastCycle = 5.4 + Double((tick * 13) % 18) / 10.0
        let avgCycle = 6.1 + Double((tick * 5) % 8) / 10.0
        let signalsToday = 120 + ((tick * 7) % 60)
        let challengesToday = 4 + ((tick * 3) % 5)
        let proposalsToday = 8 + ((tick * 2) % 7)
        let executedActions = 5 + ((tick * 11) % 9)

        return ObservatorySnapshot(
            loop: LoopMetrics(
                lastCycleDuration: lastCycle,
                averageCycleDuration: avgCycle,
                signalsToday: signalsToday,
                challengesToday: challengesToday,
                proposalsToday: proposalsToday,
                executedActions: executedActions
            ),
            field: ClashdCubeField(cells: cells, activeRoutes: routes, clusters: clusters),
            collisions: clusters,
            decisions: decisions,
            updatedAt: now
        )
    }

    private static func demoCells(tick: Int) -> [ClashdCell] {
        var cells: [ClashdCell] = []
        let hotSpots = [
            CubePosition(x: (tick / 2) % 3, y: (tick / 3) % 3, z: (tick / 5) % 3),
            CubePosition(x: (tick + 1) % 3, y: (tick + 2) % 3, z: (tick + 1) % 3)
        ]

        for z in 0..<3 {
            for y in 0..<3 {
                for x in 0..<3 {
                    let position = CubePosition(x: x, y: y, z: z)
                    let seed = x * 17 + y * 11 + z * 7 + tick * 3
                    let wave = Double((seed % 100)) / 100.0
                    let clusterId = hotSpots.contains(position) ? "cluster-\(z)-\(x)" : nil

                    let arrows = buildRouteArrows(position: position, hotspots: hotSpots)

                    cells.append(
                        ClashdCell(
                            position: position,
                            residue: wave,
                            highlightedClusterId: clusterId,
                            routeArrows: arrows
                        )
                    )
                }
            }
        }

        return cells
    }

    private static func demoRoutes(tick: Int) -> [ClashdRoute] {
        let base = CubePosition(x: tick % 3, y: (tick + 1) % 3, z: (tick + 2) % 3)
        let neighbors = [
            CubePosition(x: min(2, base.x + 1), y: base.y, z: base.z),
            CubePosition(x: base.x, y: min(2, base.y + 1), z: base.z),
            CubePosition(x: base.x, y: base.y, z: min(2, base.z + 1))
        ]

        return neighbors.enumerated().map { index, to in
            ClashdRoute(
                id: "route-\(index)-\(tick)",
                from: base,
                to: to,
                strength: 0.45 + (Double((tick + index) % 5) / 10.0)
            )
        }
    }

    private static func demoClusters(tick: Int) -> [KnowledgeCollisionCluster] {
        [
            KnowledgeCollisionCluster(
                clusterId: "kc-\(tick % 9)",
                sourceTypes: ["residue", "intent", "challenge"],
                densityScore: 0.58 + Double((tick % 7)) / 20.0,
                cubePosition: CubePosition(x: (tick + 1) % 3, y: tick % 3, z: (tick / 2) % 3),
                summary: "Cross-domain residue overlap observed between challenge and intent streams.",
                isEmergence: tick % 2 == 0
            ),
            KnowledgeCollisionCluster(
                clusterId: "kc-secondary-\(tick % 5)",
                sourceTypes: ["audit", "signal"],
                densityScore: 0.42 + Double((tick % 5)) / 25.0,
                cubePosition: CubePosition(x: (tick + 2) % 3, y: (tick + 1) % 3, z: tick % 3),
                summary: "Localized collision around repeated signal requests.",
                isEmergence: tick % 3 == 0
            )
        ]
    }

    private static func demoDecisions(tick: Int, now: Date) -> [JeevesDecisionEvent] {
        let templates: [(JeevesDecisionKind, String)] = [
            (.autoApproved, "Low-risk proposal executed"),
            (.escalated, "Orange risk proposal escalated"),
            (.autoDenied, "Policy denied high-risk proposal"),
            (.autoApproved, "Knowledge sync executed")
        ]

        return templates.enumerated().map { index, template in
            JeevesDecisionEvent(
                id: "decision-\(tick)-\(index)",
                kind: template.0,
                title: template.1,
                timestamp: now.addingTimeInterval(TimeInterval(-index * 180 - (tick % 90)))
            )
        }
    }

    private static func buildRouteArrows(position: CubePosition, hotspots: [CubePosition]) -> [String] {
        var arrows: [String] = []
        if hotspots.contains(where: { $0.x > position.x }) { arrows.append("->") }
        if hotspots.contains(where: { $0.x < position.x }) { arrows.append("<-") }
        if hotspots.contains(where: { $0.y > position.y }) { arrows.append("v") }
        if hotspots.contains(where: { $0.y < position.y }) { arrows.append("^") }
        if hotspots.contains(where: { $0.z > position.z }) { arrows.append("+z") }
        if hotspots.contains(where: { $0.z < position.z }) { arrows.append("-z") }
        return arrows
    }
}
