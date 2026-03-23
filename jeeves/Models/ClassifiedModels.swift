import Foundation

struct ClassifiedDiscovery: Codable, Identifiable, Sendable {
    var id: String { candidateId }
    let candidateId: String
    let outcomeType: String
    let domainType: String
    let candidateScore: Double
    let axes: [DiscoveryAxis]
    let explanation: String
    let residueWeight: Double
    let signalDensity: Double
    let sources: [String]
    let crossDomain: Bool
}

struct DiscoveryAxis: Codable, Sendable {
    let what: String
    let where_: String
    let time: String

    enum CodingKeys: String, CodingKey {
        case what, time
        case where_ = "where"
    }
}

struct ClassifiedResponse: Codable, Sendable {
    let classified: [ClassifiedDiscovery]
}
