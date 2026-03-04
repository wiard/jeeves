import Foundation

struct CubeCell: Codable, Hashable {
    let what: String
    let where_: String
    let when: String

    enum CodingKeys: String, CodingKey {
        case what
        case where_ = "where"
        case when
    }
}

struct CubeCard: Codable, Identifiable, Hashable {
    let id: String
    let cellIndex: Int
    let cubeCell: CubeCell
    let title: String
    let subtitle: String
    let keywords: [String]
    let ordinal: OrdinalMeta
    let sound: SoundMeta

    struct OrdinalMeta: Codable, Hashable {
        let inscriptionHint: String
        let contentHash: String
        let artifactRef: String?
    }

    struct SoundMeta: Codable, Hashable {
        let soundId: String
        let preset: String
        let params: [String: Double]
    }

    enum CodingKeys: String, CodingKey {
        case id = "cardId"
        case cellIndex
        case cubeCell
        case title
        case subtitle
        case keywords
        case ordinal
        case sound
    }
}

struct SoundProfile: Codable, Hashable {
    let preset: String
    let params: [String: Double]
    let volume: Double
    let pitchShift: Double
}

struct Hotspot: Codable, Identifiable, Hashable {
    let id: String
    let cellIndex: Int
    let cubeCell: CubeCell
    let residue: Double
    let trend: Double

    enum CodingKeys: String, CodingKey {
        case id = "cellId"
        case cellIndex
        case cubeCell
        case residue
        case trend
    }
}

struct ClusterSummary: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let cellIndex: Int
    let cubeCell: CubeCell
    let score: Double
    let signals: [String]
    let nodes: [String]

    enum CodingKeys: String, CodingKey {
        case id = "clusterId"
        case label
        case cellIndex
        case cubeCell
        case score
        case signals
        case nodes
    }
}

struct TopicItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
}

struct CubeRelatedItem: Codable, Hashable, Identifiable {
    let title: String
    let url: String

    var id: String { "\(title)|\(url)" }
}

struct CubeRelatedResources: Codable, Hashable {
    let repos: [CubeRelatedItem]
    let papers: [CubeRelatedItem]
    let posts: [CubeRelatedItem]

    static let empty = CubeRelatedResources(repos: [], papers: [], posts: [])
}

struct CubeCardsResponse: Codable, Hashable {
    let cards: [CubeCard]
}

struct CubeDrawRequest: Codable, Hashable {
    let mode: String
    let topic: String?
}

struct CubeDrawResponse: Codable, Hashable {
    let card: CubeCard
    let soundProfile: SoundProfile
    let hotspots: [Hotspot]
    let clusters: [ClusterSummary]
    let related: CubeRelatedResources
}

struct CubeTopicsResponse: Codable, Hashable {
    let topics: [TopicItem]
}

struct TopicSelectRequest: Codable, Hashable {
    let topicId: String
}

struct TopicSelectResponse: Codable, Hashable {
    let topic: TopicItem
    let hotspots: [Hotspot]
    let clusters: [ClusterSummary]
    let suggestedCards: [CubeCard]
}
