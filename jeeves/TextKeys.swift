import Foundation

enum TextKeys {
    static let appTitle = "Jeeves"

    enum Stream {
        static let header = "Mission Control"
        static let empty = "Het huis is stil."
        static let autoApproved = "Automatisch goedgekeurd"
        static let autoDenied = "Automatisch geweigerd"
        static let escalated = "Uw aandacht gevraagd, meneer"
        static let pending = "PENDING"
        static let approved = "APPROVED"
        static let denied = "DENIED"
    }

    enum Lobby {
        static let header = "Lobby"
        static let noProposals = "Geen voorstellen. Het huis is stil."
        static let approve = "Goedkeuren"
        static let deny = "Afwijzen"
        static let confirmOrange = "Risico oranje. Weet u het zeker, meneer?"
        static let confirmYes = "Ja, goedkeuren"
        static let confirmNo = "Nee, annuleer"
        static let approved = "Goedgekeurd"
        static let denied = "Afgewezen"
        static let blocked = "Geblokkeerd door beleid"
        static let approveReason = "Goedgekeurd door Jeeves iPhone"
        static let denyReason = "Afgewezen door Jeeves iPhone"
        static let deferReason = "Uitgesteld door Jeeves iPhone"
        static let pendingQueue = "Wachtende voorstellen"
        static let recentDecisions = "Recente beslissingen"
        static let noDecisions = "Nog geen beslissingen."
        static let actionReceipt = "Actie-ontvangstbewijs"
        static let actionCompleted = "Actie uitgevoerd"
        static let actionFailed = "Actie mislukt"
        static let actionKind = "Soort"
        static let actionStatus = "Status"
        static let actionResult = "Resultaat"
        static let actionDuration = "Duur"
        static let actionResultType = "Type resultaat"
        static let actionOutputObjects = "Output objecten"
        static let actionNotes = "Notities"
        static let knowledgeObjects = "Kennisgraaf"
        static let knowledgeGraph = "Kennisgraaf"
        static let rootObject = "Hoofdobject"
        static let linkedObjects = "Gekoppelde objecten"
        static let noLinkedObjects = "Geen gekoppelde objecten."
        static let extensionProposals = "Extension Proposals"
        static let noExtensionProposals = "Geen extensionvoorstellen."
        static let extensionDemoFallback = "Demo extensionvoorstellen actief (backend onbereikbaar)."
        static let inspectManifest = "Inspect Manifest"
        static let extensionPurpose = "Doel"
        static let extensionCapabilities = "Capabilities"
        static let extensionRisk = "Risico"
        static let extensionEntrypoint = "Entrypoint"
        static let extensionSource = "Bron"
        static let extensionCodeHash = "Code-hash"
        static let extensionAuditTrail = "Audit trail"
        static let extensionKnowledgeLinks = "Knowledge links"
        static let extensionReceipt = "Extension receipt"
        static let extensionGraph = "Inspect Knowledge Graph"
    }

    enum Seed {
        static let toast = "4 voorstellen gezaaid. Het huis ontwaakt."
        static let button = "Huis opnieuw vullen"
        static let seeding = "Voorstellen zaaien..."
    }

    enum Observatory {
        static let header = "Observatory"
        static let loopLabel = "Laatste cyclus"
        static let avgLabel = "Gemiddeld"
        static let signalsToday = "Signalen vandaag"
        static let challengesToday = "Challenges"
        static let proposalsToday = "Voorstellen"
        static let executedToday = "Uitgevoerd"
        static let alertUntrusted = "Onbekende agent gedetecteerd"
        static let pulseTitle = "System Pulse"
        static let emergenceTitle = "Emergence Field"
        static let lobbyTitle = "Lobby Activity"
        static let intelligenceTitle = "OpenClaw Intelligence"
        static let alertsTitle = "Alerts"
        static let refresh = "Refresh"
        static let noData = "Geen data."
        static let outsideWorldError = "Jeeves cannot see the outside world at the moment, sir."
        static let clock = "Fabric Clock"
        static let blockHeight = "Block height"
        static let tickNumber = "Tick number"
        static let source = "Clock source"
        static let updated = "Updated"
        static let activeCell = "Active cell"
        static let topRoutes = "Top routes"
        static let clusterKinds = "Cluster kinds"
        static let suggestions = "Suggestions"
        static let openChallenges = "Open"
        static let claimedChallenges = "Claimed"
        static let completedChallenges = "Completed"
        static let skillsScanned = "Skills scanned"
        static let anomalies = "Anomalies"
        static let hotCells = "Hot cells"
        static let trustModel = "Trust-model"
        static let architecture = "Architecture"
        static let surface = "Surface"
        static let severity = "Severity"
        static let kind = "Type"
        static let sources = "Sources"
        static let action = "Action"
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

    enum House {
        static let title = "De Grote Kamer"
        static let loadingStatus = "Status ophalen..."
        static let notConnectedTitle = "Niet verbonden"
        static let notConnectedDescription = "Verbind met de gateway om de status te zien."
        static let knowledgeHeader = "Observatory / Knowledge"
        static let knowledgeRefresh = "Refresh"
        static let knowledgeSignals = "Knowledge signals (24h)"
        static let knowledgeTopCells = "Top cube cells"
        static let knowledgeEmergence = "Emergence clusters"
        static let knowledgeChallenges = "Last challenges"
        static let knowledgeNoData = "Geen knowledge data."
        static let knowledgeError = "Knowledge status niet beschikbaar."
    }

    enum Settings {
        static let header = "Instellingen"
        static let gatewayUrl = "Gateway URL"
        static let token = "Conductor Token"
        static let save = "Bewaar"
        static let connected = "Verbonden"
        static let disconnected = "Niet verbonden"
        static let testConnection = "Test verbinding"
        static let proposalsFound = "proposals gevonden"
        static let tokenExpired = "Token verlopen. Genereer een nieuw token via bringup.sh"
        static let tokenValid = "Token geldig"
    }

    enum Notifications {
        static let newProposal = "Nieuw voorstel van %@: %@"
        static let emergenceDetected = "Meneer, er is iets dat uw aandacht verdient."
        static let multipleProposals = "%d voorstellen wachten."
    }
}
