import Foundation

enum TextKeys {
    static let appTitle = "Jeeves"

    enum Stream {
        static let header = "Mission Control"
        static let empty = "The system is quiet."
        static let autoApproved = "Auto-approved"
        static let autoDenied = "Auto-denied"
        static let escalated = "Your attention is needed"
        static let pending = "PENDING"
        static let approved = "APPROVED"
        static let denied = "DENIED"
    }

    enum Lobby {
        static let header = "Lobby"
        static let noProposals = "No proposals. The system is quiet."
        static let approve = "Approve"
        static let deny = "Deny"
        static let confirmOrange = "Risk is elevated. Are you sure?"
        static let confirmYes = "Yes, approve"
        static let confirmNo = "No, cancel"
        static let approved = "Approved"
        static let denied = "Denied"
        static let blocked = "Blocked by policy"
        static let approveReason = "Approved by Jeeves iPhone"
        static let denyReason = "Denied by Jeeves iPhone"
        static let deferReason = "Deferred by Jeeves iPhone"
        static let pendingQueue = "Pending decisions"
        static let recentDecisions = "Recent decisions"
        static let noDecisions = "No decisions yet."
        static let actionReceipt = "Action receipt"
        static let actionCompleted = "Action completed"
        static let actionFailed = "Action failed"
        static let actionKind = "Type"
        static let actionStatus = "Status"
        static let actionResult = "Result"
        static let actionDuration = "Duration"
        static let actionResultType = "Result type"
        static let actionOutputObjects = "Output objects"
        static let actionNotes = "Notes"
        static let knowledgeObjects = "Knowledge graph"
        static let knowledgeGraph = "Knowledge graph"
        static let rootObject = "Root object"
        static let linkedObjects = "Linked objects"
        static let noLinkedObjects = "No linked objects."
        static let extensionProposals = "Extension Proposals"
        static let noExtensionProposals = "No extension proposals."
        static let extensionDemoFallback = "Demo extension proposals active (backend unreachable)."
        static let inspectManifest = "Inspect Manifest"
        static let extensionPurpose = "Purpose"
        static let extensionCapabilities = "Capabilities"
        static let extensionRisk = "Risk"
        static let extensionEntrypoint = "Entrypoint"
        static let extensionSource = "Source"
        static let extensionCodeHash = "Code hash"
        static let extensionAuditTrail = "Audit trail"
        static let extensionKnowledgeLinks = "Knowledge links"
        static let extensionReceipt = "Extension receipt"
        static let extensionGraph = "Inspect Knowledge Graph"
    }

    enum Seed {
        static let toast = "4 proposals seeded. The system is waking up."
        static let button = "Reload system"
        static let seeding = "Seeding proposals..."
    }

    enum Observatory {
        static let header = "Observatory"
        static let loopLabel = "Last cycle"
        static let avgLabel = "Average"
        static let signalsToday = "Signals today"
        static let challengesToday = "Challenges"
        static let proposalsToday = "Proposals"
        static let executedToday = "Executed"
        static let alertUntrusted = "Unknown agent detected"
        static let pulseTitle = "System Pulse"
        static let emergenceTitle = "Pattern Detection"
        static let lobbyTitle = "Lobby Activity"
        static let intelligenceTitle = "OpenClaw Intelligence"
        static let alertsTitle = "Alerts"
        static let refresh = "Refresh"
        static let noData = "No data."
        static let outsideWorldError = "Jeeves cannot see the outside world at the moment, sir."
        static let clock = "Fabric Clock"
        static let blockHeight = "Block height"
        static let tickNumber = "Tick number"
        static let source = "Clock source"
        static let updated = "Updated"
        static let activeCell = "Active cell"
        static let topRoutes = "Top routes"
        static let clusterKinds = "Pattern types"
        static let suggestions = "Suggestions"
        static let openChallenges = "Open"
        static let claimedChallenges = "Claimed"
        static let completedChallenges = "Completed"
        static let skillsScanned = "Skills scanned"
        static let anomalies = "Anomalies"
        static let hotCells = "Hot cells"
        static let trustModel = "Trust model"
        static let architecture = "Architecture"
        static let surface = "Surface"
        static let severity = "Severity"
        static let kind = "Type"
        static let sources = "Sources"
        static let action = "Action"
    }

    enum Rooms {
        static let huishouding = "Housekeeping"
        static let buitenwereld = "Outside world"
        static let machinekamer = "Engine room"
        static let lobby = "Lobby"
    }

    enum Emergence {
        static let header = "Patterns"
        static let pattern = "Emerging pattern"
        static let sources = "sources"
        static let score = "score"
    }

    enum House {
        static let title = "System Overview"
        static let loadingStatus = "Loading status..."
        static let notConnectedTitle = "Not connected"
        static let notConnectedDescription = "Connect to the gateway to view status."
        static let knowledgeHeader = "Observatory / Knowledge"
        static let knowledgeRefresh = "Refresh"
        static let knowledgeSignals = "Knowledge signals (24h)"
        static let knowledgeTopCells = "Top cube cells"
        static let knowledgeEmergence = "Pattern clusters"
        static let knowledgeChallenges = "Last challenges"
        static let knowledgeNoData = "No knowledge data."
        static let knowledgeError = "Knowledge status not available."
    }

    enum Settings {
        static let header = "Settings"
        static let gatewayUrl = "Gateway URL"
        static let token = "Conductor Token"
        static let save = "Save"
        static let connected = "Connected"
        static let disconnected = "Not connected"
        static let testConnection = "Test connection"
        static let proposalsFound = "proposals found"
        static let tokenExpired = "Token expired. Generate a new token via bringup.sh"
        static let tokenValid = "Token valid"
    }

    enum Notifications {
        static let newProposal = "New proposal from %@: %@"
        static let emergenceDetected = "Something needs your attention."
        static let multipleProposals = "%d proposals waiting."
    }
}
