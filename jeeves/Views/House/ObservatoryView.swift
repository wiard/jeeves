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
                missionControlSection
                loopSection
                fabricSection
                lobbySection
                signalsSection
                knowledgeSection
                radarSection
                discoverySection
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

    private var missionControlSection: some View {
        Section("Mission Control") {
            if let snapshot = vm.snapshot {
                let pendingFromStream = snapshot.stream?.pendingCount ?? 0
                let pending = max(snapshot.conductor?.consentPending ?? 0, pendingFromStream)
                let streamEvents = snapshot.stream?.events.count ?? 0
                let collisions = snapshot.radarStatus?.store?.collisionCount ?? snapshot.radarCollisions.count
                let emergence = snapshot.radarStatus?.store?.emergenceCount ?? snapshot.radarEmergence.count
                let activations = snapshot.radarStatus?.store?.activationCount ?? snapshot.radarActivations.count
                let collector = snapshot.radarStatus?.collector?.isRunning

                row("Approvals required", "\(pending)")
                row("Discovery events", "\(streamEvents)")
                row("Radar activations", "\(activations)")
                row("Radar collisions", "\(collisions)")
                row("Emergence alerts", "\(emergence)")
                row("Collector", collector == nil ? "-" : (collector == true ? "running" : "stopped"))
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
                row("Run count", string(signals.runCount))
                row("Active sources", string(signals.activeSourceCount))
                row("Total signals", string(signals.totalSignals))
                row("Last run", signals.lastRunAtIso ?? "-")
                row("Last error", signals.lastError ?? "-")
            } else {
                unavailableRow
            }

            if let runtime = vm.snapshot?.signalsRuntime {
                row("Runtime run count", "\(runtime.runCount)")
                row("Runtime active sources", "\(runtime.activeSourceCount)")
                row("Runtime total signals", "\(runtime.totalSignals)")
                row("Runtime last run", runtime.lastRunAtIso ?? "-")
                row("Runtime last error", runtime.lastError ?? "-")
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

    private var radarSection: some View {
        Section("Radar") {
            if vm.status(for: .radar) == .unavailable {
                unavailableRow
            } else {
                if let status = vm.snapshot?.radarStatus?.store {
                    row("Activations", "\(status.activationCount)")
                    row("Collisions", "\(status.collisionCount)")
                    row("Emergence", "\(status.emergenceCount)")
                } else {
                    row("Activations", "-")
                    row("Collisions", "-")
                    row("Emergence", "-")
                }

                if let collector = vm.snapshot?.radarStatus?.collector {
                    row("Collector", collector.isRunning ? "running" : "stopped")
                    row("Last run", collector.lastRun ?? "-")
                } else {
                    row("Collector", "-")
                    row("Last run", "-")
                }

                let clusters = vm.snapshot?.radarClusters ?? []
                if clusters.isEmpty {
                    row("Hot cluster", "-")
                } else {
                    ForEach(Array(clusters.prefix(3).enumerated()), id: \.element.id) { index, item in
                        row("Hot cluster \(index + 1)", "\(item.label) · \(item.count)")
                    }
                }

                let topSignals = vm.snapshot?.radarStatus?.store?.topSignals ?? []
                if topSignals.isEmpty {
                    row("Top signal", "-")
                } else {
                    ForEach(Array(topSignals.prefix(3).enumerated()), id: \.offset) { index, signal in
                        row("Top signal \(index + 1)", "\(signal.source) · \(signal.title) · \(formatDouble(signal.residue))")
                    }
                }
            }
        }
    }

    private var discoverySection: some View {
        Section("Discovery") {
            if vm.status(for: .discovery) == .unavailable {
                unavailableRow
            } else {
                let stream = vm.snapshot?.stream
                row("Pending stream proposals", "\(stream?.pendingCount ?? 0)")
                row("Radar emergence", "\(vm.snapshot?.radarEmergence.count ?? 0)")
                row("Radar collisions", "\(vm.snapshot?.radarCollisions.count ?? 0)")

                let activations = vm.snapshot?.radarActivations ?? []
                if activations.isEmpty {
                    row("Activation", "-")
                } else {
                    ForEach(Array(activations.prefix(3).enumerated()), id: \.element.id) { index, activation in
                        row("Activation \(index + 1)", "\(activation.source) · \(activation.title) · \(formatDouble(activation.residue))")
                    }
                }

                let events = stream?.events ?? []
                if events.isEmpty {
                    row("Event", "-")
                } else {
                    ForEach(Array(events.prefix(8).enumerated()), id: \.element.id) { index, event in
                        let descriptor = event.event ?? event.proposalId ?? event.title ?? "-"
                        row("Event \(index + 1)", "\(event.type) · \(descriptor) · \(event.timestampIso ?? "-")")
                    }
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
