import SwiftUI

struct LogbookView: View {
    @Environment(GatewayManager.self) private var gateway
    @State private var entries: [AuditEntry] = []
    @State private var selectedPeriod: AuditPeriod = .today
    @State private var selectedFilter: AuditFilter = .all
    @State private var searchText = ""
    @State private var selectedEntry: AuditEntry?

    private var filteredEntries: [AuditEntry] {
        var result = entries

        switch selectedFilter {
        case .all:
            break
        case .blocked:
            result = result.filter { $0.status == .blocked }
        case .costs:
            result = result.filter { $0.cost != nil && $0.cost! > 0 }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.tool.localizedCaseInsensitiveContains(searchText) ||
                $0.channel.localizedCaseInsensitiveContains(searchText) ||
                ($0.reason?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    private var totalCost: Double {
        filteredEntries.compactMap(\.cost).reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AuditFilterBar(
                    selectedPeriod: $selectedPeriod,
                    selectedFilter: $selectedFilter
                )

                if filteredEntries.isEmpty {
                    ContentUnavailableView.search(text: searchText.isEmpty ? "Geen entries" : searchText)
                } else {
                    List {
                        Section {
                            ForEach(filteredEntries) { entry in
                                AuditEntryRow(entry: entry)
                                    .onTapGesture {
                                        selectedEntry = entry
                                    }
                            }
                        } footer: {
                            HStack {
                                Text("\(filteredEntries.count) acties")
                                Spacer()
                                Text(String(format: "Totaal: $%.2f", totalCost))
                                    .font(.jeevesMono)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Logboek")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .searchable(text: $searchText, prompt: "Zoek in logboek...")
            .refreshable {
                await loadEntries()
            }
            .sheet(item: $selectedEntry) { entry in
                AuditDetailView(entry: entry)
                    .presentationDetents([.medium])
            }
            .task {
                await loadEntries()
            }
            .onChange(of: selectedPeriod) {
                Task { await loadEntries() }
            }
        }
    }

    private func loadEntries() async {
        entries = (try? await gateway.fetchAudit(period: selectedPeriod)) ?? []
    }
}
