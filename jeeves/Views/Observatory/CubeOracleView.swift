import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CubeOracleView: View {
    @Environment(GatewayManager.self) private var gateway
    @Query private var connections: [GatewayConnection]

    @StateObject private var vm = CubeOracleViewModel()
    @State private var audioPlayer = CubeOracleAudioPlayer()
    @State private var showTopicPicker = false
    @State private var drawMode = "block"
    @State private var autoPlaySound = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                controlsRow
                cardPanel
                hotspotsPanel
                clustersPanel
                sharePanel
            }
            .padding()
        }
        .navigationTitle("🔮 Cube Oracle")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            await refreshAll()
        }
        .sheet(isPresented: $showTopicPicker) {
            TopicPickerSheet(
                topics: vm.topics,
                selectedTopicId: vm.selectedTopic?.id,
                onSelect: { topic in
                    Task {
                        await vm.selectTopic(topicId: topic.id)
                        await vm.drawCard(mode: drawMode, topic: topic.id)
                        if autoPlaySound {
                            playCurrentSound()
                        }
                    }
                }
            )
        }
        .task {
            if vm.cards.isEmpty && vm.currentCard == nil {
                await refreshAll()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🔮 Cube Oracle")
                .font(.jeevesHeadline)
                .foregroundStyle(Color.jeevesGold)
            Text("Tarot for emerging ideas — powered by CLASHD27")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Text("Today’s Cube Card")
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
            if let error = vm.error {
                Text(error)
                    .font(.jeevesCaption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var controlsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button("Draw Card") {
                    Task {
                        await vm.drawCard(mode: drawMode, topic: vm.selectedTopic?.id)
                        if autoPlaySound {
                            playCurrentSound()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.jeevesGold)

                Button("Pick Topic") {
                    showTopicPicker = true
                }
                .buttonStyle(.bordered)

                Picker("Mode", selection: $drawMode) {
                    Text("block").tag("block")
                    Text("day").tag("day")
                }
                .pickerStyle(.menu)
            }

            Toggle("Auto-play sound", isOn: $autoPlaySound)
                .toggleStyle(.switch)
                .font(.jeevesCaption)

            if let selectedTopic = vm.selectedTopic {
                Text("Topic: \(selectedTopic.title)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cardPanel: some View {
        GroupBox {
            if let card = vm.currentCard {
                let profile = vm.profile(for: card)
                let cardTitle = profile?.title ?? card.title
                let cardSubtitle = profile?.meaning ?? card.subtitle
                let cardShareLine = profile?.shareLine
                let symbol = profile?.symbol ?? "🔮"
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.jeevesGold.opacity(0.35), .houseDark.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 180)
                        .overlay(alignment: .bottomLeading) {
                            Text(card.id)
                                .font(.jeevesMono)
                                .padding(10)
                                .foregroundStyle(.white)
                        }

                    Text("\(symbol) \(cardTitle)")
                        .font(.jeevesHeadline)
                    Text(cardSubtitle)
                        .font(.jeevesBody)
                        .foregroundStyle(.secondary)
                    if let cardShareLine {
                        Text("“\(cardShareLine)”")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Play Sound") {
                            playCurrentSound()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("index \(card.cellIndex)")
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(card.keywords.sorted(), id: \.self) { keyword in
                                Text(keyword)
                                    .font(.jeevesCaption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.jeevesGold.opacity(0.15)))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("contentHash")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(card.ordinal.contentHash)
                                .font(.jeevesMono)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Copy") {
                                copyToClipboard(card.ordinal.contentHash)
                            }
                            .buttonStyle(.borderless)
                        }

                        if let artifact = card.ordinal.artifactRef,
                           let url = URL(string: artifact) {
                            Link("Open artifact", destination: url)
                                .font(.jeevesCaption)
                        }
                    }
                }
            } else {
                Text("No card drawn")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text("Card")
                .font(.jeevesCaption)
        }
    }

    private var hotspotsPanel: some View {
        GroupBox {
            VStack(spacing: 0) {
                if vm.hotspots.isEmpty {
                    emptyRow("Unavailable")
                } else {
                    ForEach(vm.hotspots.prefix(5)) { hotspot in
                        NavigationLink {
                            CubeCellDetailView(
                                cellIndex: hotspot.cellIndex,
                                cubeCell: hotspot.cubeCell,
                                hotspots: vm.hotspots,
                                related: vm.related,
                                onDraw: {
                                    Task {
                                        await vm.drawCard(mode: drawMode, topic: vm.selectedTopic?.id)
                                    }
                                }
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(cellLabel(hotspot.cubeCell, index: hotspot.cellIndex))
                                        .font(.jeevesCaption)
                                    Text("residue \(String(format: "%.2f", hotspot.residue))")
                                        .font(.jeevesMono)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(trendArrow(hotspot.trend)) \(String(format: "%+.2f", hotspot.trend))")
                                    .font(.jeevesMono)
                                    .foregroundStyle(hotspot.trend >= 0 ? .green : .orange)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } label: {
            Text("Hotspots")
                .font(.jeevesCaption)
        }
    }

    private var clustersPanel: some View {
        GroupBox {
            clusterContent
        } label: {
            Text("Clusters")
                .font(.jeevesCaption)
        }
    }

    @ViewBuilder
    private var clusterContent: some View {
        if vm.clusters.isEmpty {
            emptyRow("Unavailable")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(vm.clusters.prefix(3))) { cluster in
                    clusterRow(cluster)
                }
            }
        }
    }

    private func clusterRow(_ cluster: ClusterSummary) -> some View {
        NavigationLink {
            ClusterDetailView(cluster: cluster, onPlayChord: nil)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cluster.label)
                        .font(.jeevesBody)
                    Text("signals \(cluster.signals.count)")
                        .font(.jeevesMono)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.2f", cluster.score))
                    .font(.jeevesMono)
                    .foregroundStyle(Color.jeevesGold)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var sharePanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ShareLink(item: vm.sharePayload()) {
                    Label("Share my card", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                if !vm.suggestedCards.isEmpty {
                    Text("Suggested cards")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.suggestedCards.prefix(5)) { card in
                                let profile = vm.profile(for: card)
                                Button("\(profile?.symbol ?? "🔮") \(profile?.title ?? card.id)") {
                                    vm.currentCard = card
                                }
                                .font(.jeevesMono)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                            }
                        }
                    }
                }
            }
        } label: {
            Text("Share")
                .font(.jeevesCaption)
        }
    }

    private func refreshAll() async {
        await vm.configure(gateway: gateway, connection: connections.first)
        await vm.loadTopics()
        await vm.loadCards()
        if vm.currentCard == nil {
            await vm.drawCard(mode: drawMode, topic: vm.selectedTopic?.id)
            if autoPlaySound {
                playCurrentSound()
            }
        }
    }

    private func playCurrentSound() {
        guard let card = vm.currentCard else { return }
        let profile = vm.soundProfile ?? SoundProfile(preset: card.sound.preset, params: card.sound.params, volume: 0.8, pitchShift: 0)
        audioPlayer.playSound(profile: profile, soundId: card.sound.soundId)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.jeevesCaption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private func cellLabel(_ cell: CubeCell, index: Int) -> String {
        "\(cell.what) / \(cell.where_) / \(cell.when) (#\(index))"
    }

    private func trendArrow(_ trend: Double) -> String {
        trend >= 0 ? "↑" : "↓"
    }

    private func copyToClipboard(_ value: String) {
        #if os(iOS)
        UIPasteboard.general.string = value
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #endif
    }
}
