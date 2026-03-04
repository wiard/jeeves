import Foundation

enum TextKeys {
    static let appTitle = "Jeeves"

    enum Stream {
        static let header = "Stream"
        static let empty = "Het huis is stil."
        static let autoApproved = "Automatisch goedgekeurd"
        static let autoDenied = "Automatisch geweigerd"
        static let escalated = "Uw aandacht gevraagd, meneer"
    }

    enum Lobby {
        static let header = "Lobby"
        static let noProposals = "Geen voorstellen in de wachtkamer, meneer."
        static let approve = "Goedkeuren"
        static let deny = "Afwijzen"
        static let confirmOrange = "Risico oranje. Weet u het zeker, meneer?"
        static let approved = "Goedgekeurd"
        static let denied = "Afgewezen"
        static let blocked = "Geblokkeerd door beleid"
    }

    enum Observatory {
        static let header = "Observatory"
        static let loopLabel = "Laatste cyclus"
        static let avgLabel = "Gemiddeld"
        static let signalsToday = "Signalen vandaag"
        static let challengesToday = "Challenges"
        static let proposalsToday = "Voorstellen"
        static let executedToday = "Uitgevoerd"
    }

    enum Rooms {
        static let huishouding = "Huishouding"
        static let buitenwereld = "Buitenwereld"
        static let machinekamer = "Machinekamer"
        static let lobby = "Lobby"
    }

    enum Emergence {
        static let header = "Emergence"
        static let pattern = "Emergent patroon"
        static let sources = "bronnen"
        static let score = "score"
    }

    enum Settings {
        static let header = "Instellingen"
        static let gatewayUrl = "Gateway URL"
        static let token = "Conductor Token"
        static let save = "Bewaar"
        static let connected = "Verbonden"
        static let disconnected = "Niet verbonden"
    }

    enum Notifications {
        static let newProposal = "Nieuw voorstel van %@: %@"
        static let emergenceDetected = "Meneer, er is iets dat uw aandacht verdient."
        static let multipleProposals = "%d voorstellen wachten."
    }
}
