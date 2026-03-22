import SwiftUI

struct ResearchView: View {
    @Environment(GatewayManager.self) private var gateway
    @StateObject private var viewModel = ResearchViewModel()
    @State private var shareURLs: [URL] = []

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.99, green: 0.97, blue: 0.96),
                        Color(red: 0.98, green: 0.95, blue: 0.93),
                        Color(red: 0.97, green: 0.97, blue: 0.99)
                    ]
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        InstrumentRoleHeader(
                            eyebrow: "Onderzoek",
                            title: researchTitle,
                            summary: researchSummary,
                            accent: .jeevesLogoRed,
                            metrics: [
                                InstrumentRoleMetric(label: "Domeinen", value: "\(viewModel.domains.count)"),
                                InstrumentRoleMetric(label: "Gaps", value: "\(viewModel.jobStatus?.foundGapCount ?? 0)")
                            ]
                        )

                        if let error = viewModel.error {
                            Text(error)
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.9))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.jeevesLogoRed.opacity(0.14), lineWidth: 1)
                                        )
                                )
                        }

                        if viewModel.isRunning {
                            progressCard
                        } else if let status = viewModel.jobStatus, status.isComplete {
                            resultCard(status)
                        } else {
                            domainsCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Onderzoek")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                viewModel.configure(gateway: gateway)
                if viewModel.domains.isEmpty {
                    await viewModel.loadDomains()
                }
            }
            .refreshable {
                viewModel.configure(gateway: gateway)
                await viewModel.loadDomains()
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        viewModel.configure(gateway: gateway)
                        await viewModel.loadDomains()
                    }
                }
            }
            #if canImport(UIKit)
            .sheet(isPresented: shareSheetPresented) {
                ActivityShareSheet(items: shareURLs)
            }
            #endif
        }
    }

    private var researchTitle: String {
        if viewModel.isRunning {
            return "Onderzoek loopt"
        }
        if let status = viewModel.jobStatus, status.isComplete {
            return "Onderzoek afgerond"
        }
        return "Kies een domein"
    }

    private var researchSummary: String {
        if viewModel.isRunning {
            return "CLASHD27 verzamelt nu signalen en papers. Jeeves laat de voortgang rustig en leesbaar zien."
        }
        if let status = viewModel.jobStatus, status.isComplete {
            return "\(status.foundGapCount) gaps gevonden in \(status.displayDomainName)."
        }
        return "Start een bounded research run en laat de resultaten daarna terugkomen in de Bieb."
    }

    private var domainsCard: some View {
        InstrumentSectionPanel(
            eyebrow: "Domeinen",
            title: "Kies een onderzoeksveld",
            subtitle: "Tap op een domein om meteen een governed research run te starten.",
            accent: .jeevesLogoRed,
            metric: viewModel.domains.isEmpty ? "Leeg" : "\(viewModel.domains.count)"
        ) {
            if viewModel.domains.isEmpty {
                Text("Nog geen onderzoeksdomeinen beschikbaar.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(viewModel.domains) { domain in
                    Button {
                        Task {
                            await viewModel.startResearch(domainId: domain.id)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(domain.displayName)
                                    .font(.jeevesBody.weight(.semibold))
                                    .foregroundStyle(Color.jeevesInk)
                                Spacer()
                                Text("\(domainGapCount(for: domain)) gaps")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.jeevesLogoRed)
                            }

                            Text(domain.displaySummary)
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let insight = viewModel.domainInsights[domain.id] {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        detailChip("\(insight.gapCount) beschikbaar")
                                        if let lastDate = insight.lastGapDate {
                                            detailChip("Laatste: \(lastDate)")
                                        }
                                    }

                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.jeevesLine.opacity(0.5))
                                            Capsule()
                                                .fill(Color.jeevesLogoRed)
                                                .frame(width: max(10, geometry.size.width * insight.averageScore))
                                        }
                                    }
                                    .frame(height: 8)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.94))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.jeevesLogoRed.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var progressCard: some View {
        InstrumentSectionPanel(
            eyebrow: "Voortgang",
            title: "Onderzoek bezig",
            subtitle: "Jeeves volgt de run zonder de operator te overladen.",
            accent: .jeevesLogoRed
        ) {
            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .scaleEffect(1.7)
                    .tint(.jeevesLogoRed)
                    .padding(.top, 10)

                Text(viewModel.jobStatus?.phaseText ?? "Collecting papers...")
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)

                Text("\(viewModel.jobStatus?.foundGapCount ?? 0) gaps gevonden tot nu toe")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)

                Button("Annuleer") {
                    viewModel.cancelTracking()
                }
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.consentRed)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func resultCard(_ status: ResearchJobStatus) -> some View {
        InstrumentSectionPanel(
            eyebrow: "Resultaat",
            title: "\(status.foundGapCount) gaps gevonden in \(status.displayDomainName)",
            subtitle: "De run is klaar. Bekijk de uitkomst in de Bieb of exporteer de PDF-bundel.",
            accent: .jeevesLogoRed
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Button("Bekijk in Bieb") {
                    NotificationCenter.default.post(name: .jeevesOpenVandaagTab, object: nil)
                }
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.jeevesLogoRed)
                )

                Button("Exporteer alle PDFs") {
                    Task {
                        do {
                            shareURLs = try await viewModel.exportAllPDFs()
                        } catch {
                            viewModel.error = error.localizedDescription
                        }
                    }
                }
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(viewModel.canExportPDFs ? Color.jeevesInk : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(viewModel.canExportPDFs ? 0.94 : 0.78))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.jeevesLogoRed.opacity(0.12), lineWidth: 1)
                        )
                )
                .disabled(!viewModel.canExportPDFs)

                if !viewModel.resultGaps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top gaps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.jeevesLogoRed)

                        ForEach(viewModel.resultGaps) { gap in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    Text(gap.title)
                                        .font(.jeevesBody.weight(.semibold))
                                        .foregroundStyle(Color.jeevesInk)
                                        .lineLimit(2)

                                    Spacer(minLength: 8)

                                    Text(gap.scoreBadge)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(scoreColor(for: gap))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(scoreColor(for: gap).opacity(0.14))
                                        )
                                }

                                Text(gap.hypothesis)
                                    .font(.jeevesBody)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)

                                Button {
                                    Task {
                                        do {
                                            shareURLs = [try await viewModel.exportPDF(for: gap)]
                                        } catch {
                                            viewModel.error = error.localizedDescription
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if viewModel.exportingGapId == gap.id {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(.white)
                                        }
                                        Text("Exporteer PDF")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(.white)
                                    .background(
                                        Capsule()
                                            .fill(Color.jeevesSky)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.exportingGapId != nil && viewModel.exportingGapId != gap.id)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.9))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.jeevesLogoRed.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.jeevesSubtleText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.jeevesLine.opacity(0.28))
            )
    }

    private func domainGapCount(for domain: ResearchDomain) -> Int {
        viewModel.domainInsights[domain.id]?.gapCount ?? domain.displayGapsCount
    }

    private func scoreColor(for gap: ResearchGapCard) -> Color {
        switch gap.scoreFraction {
        case 0.7...:
            return .consentGreen
        case 0.5..<0.7:
            return .orange
        default:
            return .gray
        }
    }

    private var shareSheetPresented: Binding<Bool> {
        Binding(
            get: { !shareURLs.isEmpty },
            set: { isPresented in
                if !isPresented {
                    shareURLs = []
                }
            }
        )
    }
}
