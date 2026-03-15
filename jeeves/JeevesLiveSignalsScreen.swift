import SwiftUI

struct JeevesLiveSignalsScreen: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoadingGovernedSignals {
                    ProgressView("Loading governed signals...")
                        .padding()
                }

                if let error = liveSignalsError {
                    Text("Governed gateway status: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }

                JeevesLiveSignalsPanel(
                    runtime: poller.signalsRuntimeSnapshot,
                    operatorMemory: poller.operatorMemorySnapshot
                )
            }
            .padding()
        }
        .navigationTitle("Mission Control")
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .onChange(of: gateway.isConnected) {
            if gateway.isConnected {
                Task { await refresh() }
            }
        }
    }

    private var isLoadingGovernedSignals: Bool {
        !poller.hasLoadedOnce
            && poller.signalsRuntimeSnapshot == nil
            && poller.operatorMemorySnapshot == nil
    }

    private var liveSignalsError: String? {
        if let runtimeError = poller.signalsRuntimeSnapshot?.lastError,
           !runtimeError.isEmpty {
            return runtimeError
        }
        return poller.lastRefreshError
    }

    private func refresh() async {
        await poller.refresh(gateway: gateway)
    }
}

#Preview {
    NavigationStack {
        JeevesLiveSignalsScreen()
    }
    .environment(GatewayManager())
    .environment(ProposalPoller())
}
