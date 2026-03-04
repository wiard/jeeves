import SwiftUI
import SwiftData

struct ObservatoryView: View {
    @Environment(GatewayManager.self) private var gateway
    @Query private var connections: [GatewayConnection]
    @StateObject private var vm = ObservatoryViewModel()

    var body: some View {
        NavigationStack {
            List {
                oracleSection
                loopSection
                fabricSection
                lobbySection
                signalsSection
                knowledgeSection
                alertsSection
            }
            .navigationTitle("Observatory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await vm.refresh(gateway: gateway, connection: connections.first)
            }
            .task {
                if vm.snapshot == nil {
                    await vm.refresh(gateway: gateway, connection: connections.first)
                }
            }
        }
    }

    private var oracleSection: some View {
        Section("Oracle") {
            NavigationLink("🔮 Cube Oracle") {
                CubeOracleView()
            }
            .font(.jeevesBody)
        }
    }

    private var loopSection: some View {
        Section("Loop") {
            if vm.status(for: .loop) == .unavailable {
                unavailableRow
            } else if let conductor = vm.snapshot?.conductor {
                row("Cycle stage", conductor.cycleStage)
                row("Consent pending", "\(conductor.consentPending)")
                row("Budget remaining", formatDouble(conductor.budget.remaining))
                row("Budget hard stop", conductor.budget.hardStop ? "true" : "false")
                row("Kill switch", conductor.killSwitch.active ? "active" : "armed")
                row("Updated", conductor.updatedAtIso)
            } else {
                unavailableRow
            }
        }
    }

    private var fabricSection: some View {
        Section("Fabric") {
            if vm.status(for: .fabric) == .unavailable {
                unavailableRow
            } else {
                if let clock = vm.snapshot?.fabricClock {
                    row("Clock source", clock.source)
                    row("Tick", "\(clock.tickN)")
                    row("Clock time", clock.timeIso ?? "-")
                } else {
                    row("Clock source", "-")
                    row("Tick", "-")
                    row("Clock time", "-")
                }

                if let emergence = vm.snapshot?.fabricEmergence {
                    row("Strongest cell", emergence.strongestCell ?? "-")
                    row("Warm layer", emergence.warmLayer ?? "-")
                    row("Clusters", "\(emergence.clusters.count)")
                    let suggestions = Array(emergence.suggestions.prefix(3))
                    if suggestions.isEmpty {
                        row("Suggestion", "-")
                    } else {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                            row("Suggestion \(index + 1)", suggestion)
                        }
                    }
                } else {
                    row("Strongest cell", "-")
                    row("Warm layer", "-")
                    row("Clusters", "-")
                    row("Suggestion", "-")
                }
            }
        }
    }

    private var lobbySection: some View {
        Section("Lobby") {
            if vm.status(for: .lobby) == .unavailable {
                unavailableRow
            } else {
                let challenges = vm.snapshot?.lobbyOpenChallenges ?? []
                row("Open challenges", "\(challenges.count)")
                ForEach(Array(challenges.prefix(5).enumerated()), id: \.element.id) { index, challenge in
                    let title = challenge.title ?? "Untitled"
                    let key = challenge.key ?? "-"
                    row("Challenge \(index + 1)", "\(title) · \(key)")
                }
            }
        }
    }

    private var signalsSection: some View {
        Section("Signals") {
            if vm.status(for: .signals) == .unavailable {
                unavailableRow
            } else if let signals = vm.snapshot?.signals {
                row("Signals today", string(signals.signalsToday))
                row("Challenges today", string(signals.challengesToday))
                row("Proposals today", string(signals.proposalsToday))
                row("Executed actions", string(signals.executedActions))
            } else {
                unavailableRow
            }
        }
    }

    private var knowledgeSection: some View {
        Section("Knowledge") {
            if vm.status(for: .knowledge) == .unavailable {
                unavailableRow
            } else {
                if let status = vm.snapshot?.knowledgeStatus {
                    row("Signals count", "\(status.last24hSignalsCount)")
                    row("Status emergence", "\(status.emergenceClustersCount)")
                } else {
                    row("Signals count", "-")
                    row("Status emergence", "-")
                }

                if let emergence = vm.snapshot?.knowledgeEmergence {
                    row("Top emergence count", "\(emergence.clusters.count)")
                } else {
                    row("Top emergence count", "-")
                }
            }
        }
    }

    private var alertsSection: some View {
        Section("Alerts") {
            if vm.status(for: .alerts) == .unavailable {
                unavailableRow
            } else {
                let alerts = vm.snapshot?.alerts ?? []
                if alerts.isEmpty {
                    row("Latest", "-")
                } else {
                    ForEach(Array(alerts.prefix(10).enumerated()), id: \.element.id) { index, alert in
                        let title = alert.title ?? "Untitled"
                        let summary = alert.summary ?? "-"
                        let time = alert.timestampIso ?? "-"
                        row("Alert \(index + 1)", "\(title) · \(summary) · \(time)")
                    }
                }
            }
        }
    }

    private var unavailableRow: some View {
        Text("Unavailable")
            .font(.jeevesMono)
            .foregroundStyle(.secondary)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.jeevesMono)
                .multilineTextAlignment(.trailing)
        }
        .font(.jeevesCaption)
    }

    private func string(_ value: Int?) -> String {
        value.map(String.init) ?? "-"
    }

    private func formatDouble(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
