import Foundation
import Observation

@MainActor
@Observable
final class RadarViewModel {
    var layers: [DiscoveryLayer] = []
    var selectedLayerIndex: Int = 0

    func load() async {
        layers = Self.mockLayers()
    }

    var selectedLayer: DiscoveryLayer? {
        guard layers.indices.contains(selectedLayerIndex) else { return nil }
        return layers[selectedLayerIndex]
    }

    private static func mockLayers() -> [DiscoveryLayer] {
        [
            DiscoveryLayer(
                id: "discussion",
                title: "Discussion",
                cells: [
                    .init(id: "d1", title: "AI × Tech", subtitle: "Discussion", intensity: .rising, clusterCount: 3, hints: [
                        .init(id: "h1", topic: "Execution layers", why: "Discussie versnelt rond lichte agent-runtimes.", sourceCount: 3, noveltyScore: 0.82, pressureScore: 0.78)
                    ]),
                    .init(id: "d2", title: "AI × Gov", subtitle: "Discussion", intensity: .normal, clusterCount: 1, hints: []),
                    .init(id: "d3", title: "AI × Econ", subtitle: "Discussion", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "d4", title: "Geo × Tech", subtitle: "Discussion", intensity: .normal, clusterCount: 1, hints: []),
                    .init(id: "d5", title: "Geo × Gov", subtitle: "Discussion", intensity: .rising, clusterCount: 2, hints: [
                        .init(id: "h2", topic: "Sanctions narrative shift", why: "Narratief verandert in meerdere bronnen tegelijk.", sourceCount: 4, noveltyScore: 0.63, pressureScore: 0.84)
                    ]),
                    .init(id: "d6", title: "Geo × Econ", subtitle: "Discussion", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "d7", title: "Infra × Tech", subtitle: "Discussion", intensity: .hot, clusterCount: 4, hints: [
                        .init(id: "h3", topic: "Minimal runtimes", why: "Nieuwe focus op eenvoud en portable execution.", sourceCount: 5, noveltyScore: 0.88, pressureScore: 0.91)
                    ]),
                    .init(id: "d8", title: "Infra × Gov", subtitle: "Discussion", intensity: .normal, clusterCount: 1, hints: []),
                    .init(id: "d9", title: "Infra × Econ", subtitle: "Discussion", intensity: .quiet, clusterCount: 0, hints: [])
                ]
            ),
            DiscoveryLayer(
                id: "research",
                title: "Research",
                cells: [
                    .init(id: "r1", title: "AI × Tech", subtitle: "Research", intensity: .normal, clusterCount: 2, hints: []),
                    .init(id: "r2", title: "AI × Gov", subtitle: "Research", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "r3", title: "AI × Econ", subtitle: "Research", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "r4", title: "Geo × Tech", subtitle: "Research", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "r5", title: "Geo × Gov", subtitle: "Research", intensity: .normal, clusterCount: 1, hints: []),
                    .init(id: "r6", title: "Geo × Econ", subtitle: "Research", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "r7", title: "Infra × Tech", subtitle: "Research", intensity: .rising, clusterCount: 2, hints: []),
                    .init(id: "r8", title: "Infra × Gov", subtitle: "Research", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "r9", title: "Infra × Econ", subtitle: "Research", intensity: .quiet, clusterCount: 0, hints: [])
                ]
            ),
            DiscoveryLayer(
                id: "code",
                title: "Code",
                cells: [
                    .init(id: "c1", title: "AI × Tech", subtitle: "Code", intensity: .hot, clusterCount: 4, hints: []),
                    .init(id: "c2", title: "AI × Gov", subtitle: "Code", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "c3", title: "AI × Econ", subtitle: "Code", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "c4", title: "Geo × Tech", subtitle: "Code", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "c5", title: "Geo × Gov", subtitle: "Code", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "c6", title: "Geo × Econ", subtitle: "Code", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "c7", title: "Infra × Tech", subtitle: "Code", intensity: .hot, clusterCount: 5, hints: []),
                    .init(id: "c8", title: "Infra × Gov", subtitle: "Code", intensity: .quiet, clusterCount: 0, hints: []),
                    .init(id: "c9", title: "Infra × Econ", subtitle: "Code", intensity: .quiet, clusterCount: 0, hints: [])
                ]
            )
        ]
    }
}
