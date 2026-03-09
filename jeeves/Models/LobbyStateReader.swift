import Foundation

/// Lightweight ScreenStateReadable for the Lobby screen.
/// Wraps ProposalPoller's extension data without duplicating conformance.
@MainActor
struct LobbyStateReader: ScreenStateReadable {
    let poller: ProposalPoller

    var screenId: AppScreen { .lobby }

    func summary() -> ScreenStateSummary {
        let extensions = poller.extensionProposals.count
        let pending = poller.extensionProposals.filter(\.isPending).count
        let tools = poller.incomingTools.count

        var highlights: [String] = []
        if pending > 0 { highlights.append("\(pending) extensies wachten op review") }
        if tools > 0 { highlights.append("\(tools) inkomende tools") }
        if extensions > 0 { highlights.append("\(extensions) extensies totaal") }

        let headline: String
        if pending > 0 {
            headline = "\(pending) extensie(s) wachten op goedkeuring, \(tools) inkomende tools."
        } else if extensions > 0 {
            headline = "\(extensions) extensie(s) geladen, geen wachtend."
        } else {
            headline = "Geen extensies beschikbaar."
        }

        return ScreenStateSummary(
            screen: .lobby,
            headline: headline,
            itemCount: extensions + tools,
            highlights: highlights,
            isEmpty: extensions == 0 && tools == 0
        )
    }
}
