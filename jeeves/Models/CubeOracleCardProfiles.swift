import Foundation

struct CubeOracleCardProfile: Identifiable, Hashable {
    let index: Int
    let title: String
    let cubeCell: CubeCell
    let meaning: String
    let symbol: String
    let shareLine: String

    var id: Int { index }
    var cardId: String { String(format: "CARD:%03d", index) }

    static let all: [CubeOracleCardProfile] = [
        .init(index: 1, title: "The Contract", cubeCell: .init(what: "trust-model", where_: "internal", when: "historical"), meaning: "Oude regels bepalen nog steeds het spel.", symbol: "📜", shareLine: "The Contract — oude afspraken sturen de toekomst."),
        .init(index: 2, title: "The Guardian", cubeCell: .init(what: "trust-model", where_: "internal", when: "current"), meaning: "Bescherming en veiligheid staan centraal.", symbol: "🛡️", shareLine: "The Guardian — vertrouwen wordt actief bewaakt."),
        .init(index: 3, title: "The Covenant", cubeCell: .init(what: "trust-model", where_: "internal", when: "emerging"), meaning: "Nieuwe vormen van samenwerking ontstaan.", symbol: "🤝", shareLine: "The Covenant — nieuwe bondgenootschappen worden gevormd."),
        .init(index: 4, title: "The Gatekeeper", cubeCell: .init(what: "trust-model", where_: "external", when: "historical"), meaning: "Toegang werd vroeger gecontroleerd door centrale machten.", symbol: "🚪", shareLine: "The Gatekeeper — wie controleert de toegang?"),
        .init(index: 5, title: "The Signal", cubeCell: .init(what: "trust-model", where_: "external", when: "current"), meaning: "De buitenwereld zendt duidelijke signalen.", symbol: "📡", shareLine: "The Signal — de wereld spreekt."),
        .init(index: 6, title: "The Consensus", cubeCell: .init(what: "trust-model", where_: "external", when: "emerging"), meaning: "Nieuwe vormen van gedeeld vertrouwen ontstaan.", symbol: "🌐", shareLine: "The Consensus — vertrouwen wordt collectief."),
        .init(index: 7, title: "The Kernel", cubeCell: .init(what: "trust-model", where_: "engine", when: "historical"), meaning: "De basisregels van een systeem.", symbol: "⚙️", shareLine: "The Kernel — het hart van het systeem."),
        .init(index: 8, title: "The Validator", cubeCell: .init(what: "trust-model", where_: "engine", when: "current"), meaning: "Waarheid wordt gecontroleerd.", symbol: "✔️", shareLine: "The Validator — waarheid wordt getest."),
        .init(index: 9, title: "The Protocol", cubeCell: .init(what: "trust-model", where_: "engine", when: "emerging"), meaning: "Nieuwe regels van samenwerking.", symbol: "🔗", shareLine: "The Protocol — de regels van morgen."),
        .init(index: 10, title: "The Room", cubeCell: .init(what: "surface", where_: "internal", when: "historical"), meaning: "De plek waar ideeën ooit begonnen.", symbol: "🏠", shareLine: "The Room — hier begon het."),
        .init(index: 11, title: "The Conversation", cubeCell: .init(what: "surface", where_: "internal", when: "current"), meaning: "Nieuwe ideeën ontstaan door dialoog.", symbol: "💬", shareLine: "The Conversation — ideeën bewegen."),
        .init(index: 12, title: "The Whisper", cubeCell: .init(what: "surface", where_: "internal", when: "emerging"), meaning: "Iets nieuws begint stil.", symbol: "🫧", shareLine: "The Whisper — een idee dat net geboren wordt."),
        .init(index: 13, title: "The Channel", cubeCell: .init(what: "surface", where_: "external", when: "historical"), meaning: "Communicatie vormt netwerken.", symbol: "📺", shareLine: "The Channel — verbinding vormt beweging."),
        .init(index: 14, title: "The Relay", cubeCell: .init(what: "surface", where_: "external", when: "current"), meaning: "Informatie beweegt snel.", symbol: "🔁", shareLine: "The Relay — ideeën reizen."),
        .init(index: 15, title: "The Echo", cubeCell: .init(what: "surface", where_: "external", when: "emerging"), meaning: "Nieuwe ideeën beginnen te resoneren.", symbol: "🔊", shareLine: "The Echo — een idee wordt gehoord."),
        .init(index: 16, title: "The Interface", cubeCell: .init(what: "surface", where_: "engine", when: "historical"), meaning: "De plek waar mens en machine elkaar ontmoeten.", symbol: "🖥️", shareLine: "The Interface — waar intentie en uitvoering elkaar raken."),
        .init(index: 17, title: "The Portal", cubeCell: .init(what: "surface", where_: "engine", when: "current"), meaning: "Nieuwe toegang tot kennis.", symbol: "🌀", shareLine: "The Portal — nieuwe toegang tot kennis opent zich."),
        .init(index: 18, title: "The Mirror", cubeCell: .init(what: "surface", where_: "engine", when: "emerging"), meaning: "Technologie reflecteert onszelf.", symbol: "🪞", shareLine: "The Mirror — technologie reflecteert wie wij zijn."),
        .init(index: 19, title: "The Foundation", cubeCell: .init(what: "architecture", where_: "internal", when: "historical"), meaning: "De basis waarop alles rust.", symbol: "🧱", shareLine: "The Foundation — verborgen structuren dragen verandering."),
        .init(index: 20, title: "The Builder", cubeCell: .init(what: "architecture", where_: "internal", when: "current"), meaning: "De architect van nieuwe systemen.", symbol: "🛠️", shareLine: "The Builder — systemen krijgen vorm door gerichte keuzes."),
        .init(index: 21, title: "The Blueprint", cubeCell: .init(what: "architecture", where_: "internal", when: "emerging"), meaning: "Nieuwe ontwerpen verschijnen.", symbol: "📐", shareLine: "The Blueprint — morgen verschijnt eerst als ontwerp."),
        .init(index: 22, title: "The Network", cubeCell: .init(what: "architecture", where_: "external", when: "historical"), meaning: "Verbonden systemen.", symbol: "🕸️", shareLine: "The Network — verbindingen overleven hun makers."),
        .init(index: 23, title: "The Bridge", cubeCell: .init(what: "architecture", where_: "external", when: "current"), meaning: "Werelden worden verbonden.", symbol: "🌉", shareLine: "The Bridge — verre werelden worden een pad."),
        .init(index: 24, title: "The Constellation", cubeCell: .init(what: "architecture", where_: "external", when: "emerging"), meaning: "Nieuwe netwerken ontstaan.", symbol: "✨", shareLine: "The Constellation — nieuwe patronen verbinden het onbekende."),
        .init(index: 25, title: "The Machine", cubeCell: .init(what: "architecture", where_: "engine", when: "historical"), meaning: "Mechanische systemen uit het verleden.", symbol: "⚙️", shareLine: "The Machine — oude motoren sturen nog steeds het nu."),
        .init(index: 26, title: "The Engine", cubeCell: .init(what: "architecture", where_: "engine", when: "current"), meaning: "De motor van verandering.", symbol: "🚀", shareLine: "The Engine — momentum maakt van plannen werkelijkheid."),
        .init(index: 27, title: "The Singularity", cubeCell: .init(what: "architecture", where_: "engine", when: "emerging"), meaning: "Een nieuw tijdperk begint.", symbol: "🌟", shareLine: "The Singularity — een nieuwe wereld wordt geboren.")
    ]

    static func profile(for card: CubeCard) -> CubeOracleCardProfile? {
        let idMatch = normalizedCardId(card.id)
        if let direct = all.first(where: { $0.cardId == idMatch }) {
            return direct
        }
        if let byCell = all.first(where: { $0.index == card.cellIndex || $0.index - 1 == card.cellIndex }) {
            return byCell
        }
        return all.first {
            normalized($0.cubeCell.what) == normalized(card.cubeCell.what) &&
            normalized($0.cubeCell.where_) == normalized(card.cubeCell.where_) &&
            normalized($0.cubeCell.when) == normalized(card.cubeCell.when)
        }
    }

    static func canonicalCards() -> [CubeCard] {
        all.map { profile in
            CubeCard(
                id: profile.cardId,
                cellIndex: profile.index,
                cubeCell: profile.cubeCell,
                title: profile.title,
                subtitle: profile.meaning,
                keywords: [profile.cubeCell.what, profile.cubeCell.where_, profile.cubeCell.when],
                ordinal: .init(
                    inscriptionHint: "bitmap://cube-oracle/\(String(format: "%03d", profile.index))",
                    contentHash: "sha256:\(String(format: "%08x", profile.index * 2654435761 & 0xffffffff))",
                    artifactRef: nil
                ),
                sound: .init(
                    soundId: "SND:\(String(format: "%03d", profile.index))",
                    preset: "glitch-echo",
                    params: ["color": Double(profile.index % 7) / 7.0]
                )
            )
        }
    }

    private static func normalizedCardId(_ raw: String) -> String {
        let upper = raw.uppercased()
        if upper.hasPrefix("CARD:") {
            let number = upper.replacingOccurrences(of: "CARD:", with: "")
            if let value = Int(number) {
                return String(format: "CARD:%03d", value)
            }
        }
        return upper
    }

    private static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
