import Foundation

struct DiscoveryLayer: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let cells: [DiscoveryCell]
}

struct DiscoveryCell: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let intensity: RadarIntensity
    let clusterCount: Int
    let hints: [DiscoveryHint]
}

struct DiscoveryHint: Identifiable, Hashable, Sendable {
    let id: String
    let topic: String
    let why: String
    let sourceCount: Int
    let noveltyScore: Double
    let pressureScore: Double
}

enum RadarIntensity: String, Codable, Hashable, Sendable {
    case quiet
    case normal
    case rising
    case hot
}
