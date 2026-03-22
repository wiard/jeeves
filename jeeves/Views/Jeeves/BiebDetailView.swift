import SwiftUI

struct BiebDetailView: View {
    let item: BiebLatestCell
    @ObservedObject var viewModel: VandaagViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var pendingDecision: String?
    @State private var isResolvingDecision = false
    @State private var canDecide = false
    @State private var isExportingPDF = false
    @State private var shareURLs: [URL] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    explanationBar

                    VStack(alignment: .leading, spacing: 10) {
                        Text(detailTitle)
                            .font(.jeevesLargeTitle)
                            .foregroundStyle(Color.jeevesInk)

                        HStack(spacing: 10) {
                            Text(item.domain.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(domainColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(domainColor.opacity(0.12))
                                )

                            Text(scoreLabel)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Color.jeevesLogoRed)
                        }

                    }

                    detailSection(
                        label: "HYPOTHESE",
                        title: "De volledige hypothese",
                        body: item.hypothesis ?? item.claim ?? item.title ?? item.label
                    )

                    detailSection(
                        label: "KANS",
                        title: opportunityText,
                        body: opportunityExplanation
                    )

                    detailSection(
                        label: "DOMEIN",
                        title: domainText,
                        body: domainExplanation
                    )

                    detailSection(
                        label: "KENNISEIGENSCHAP",
                        title: propertyNameText ?? "Geen eigenschap beschikbaar",
                        body: propertySectionBody
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reden (optioneel)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.jeevesLogoRed)

                        TextField("Waarom keur je dit goed of af?", text: $reason, axis: .vertical)
                            .font(.jeevesBody)
                            .foregroundStyle(Color.jeevesInk)
                            .lineLimit(2...4)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.94))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.jeevesLine.opacity(0.7), lineWidth: 1)
                                    )
                            )
                    }

                    if let error = viewModel.error {
                        Text(error)
                            .font(.jeevesBody)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if canDecide {
                        HStack(spacing: 12) {
                            decisionButton(
                                title: "Goedkeuren",
                                tint: .consentGreen,
                                decision: "approve"
                            )

                            decisionButton(
                                title: "Afwijzen",
                                tint: .consentRed,
                                decision: "deny"
                            )
                        }
                    } else if isResolvingDecision {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.jeevesLogoRed)
                            Text("Beslisroute wordt gecontroleerd...")
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Beslissing via Beslissingen tab")
                            .font(.jeevesBody.weight(.semibold))
                            .foregroundStyle(Color.jeevesLogoRed)
                    }

                    Button {
                        isExportingPDF = true
                        Task {
                            do {
                                let url = try await viewModel.exportPDF(for: item)
                                await MainActor.run {
                                    shareURLs = [url]
                                    isExportingPDF = false
                                }
                            } catch {
                                await MainActor.run {
                                    viewModel.error = error.localizedDescription
                                    isExportingPDF = false
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if isExportingPDF {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                            Text(isExportingPDF ? "PDF genereren..." : "Exporteer PDF")
                                .font(.jeevesBody.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.jeevesSky)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isExportingPDF)
                }
                .padding(20)
            }
            .background(Color.jeevesMist.ignoresSafeArea())
            .navigationTitle("Bieb detail")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            viewModel.clearError()
        }
        .task(id: item.id) {
            await loadDecisionRoute()
        }
        #if canImport(UIKit)
        .sheet(isPresented: shareSheetPresented) {
            ActivityShareSheet(items: shareURLs)
        }
        #endif
    }

    private var detailTitle: String {
        item.displayTitle
    }

    private var explanationBar: some View {
        Text("Dit is een gap — een ontbrekend experiment dat CLASHD27 detecteerde tussen twee kennisdomeinen.")
            .font(.system(size: 12))
            .foregroundStyle(Color.jeevesSubtleText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.98, blue: 0.98))
            )
    }

    private var scoreLabel: String {
        String(format: "%.0f%%", item.normalizedScore * 100)
    }

    private var domainColor: Color {
        let palette: [Color] = [.jeevesLogoRed, .jeevesSky, .jeevesMint, .jeevesGold, .jeevesTeal]
        let index = abs(item.domain.lowercased().hashValue) % palette.count
        return palette[index]
    }

    private func opportunityScoreLabel(_ score: Double) -> String {
        String(format: "%.0f%%", min(max(score, 0), 1) * 100)
    }

    private var opportunityBadgeText: String? {
        guard let label = item.opportunityLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.isEmpty else {
            return nil
        }
        guard let score = item.opportunityScore else {
            return label
        }
        return "\(label) · \(opportunityScoreLabel(score))"
    }

    private var opportunityText: String {
        opportunityBadgeText ?? (item.opportunityLabel?.nilIfEmpty ?? "Geen opportunity beschikbaar")
    }

    private var opportunityExplanation: String {
        let label = item.opportunityLabel?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch label {
        case "vroeg stadium":
            return "Vroeg stadium betekent weinig concurrentie in dit onderzoeksdomein."
        case "opkomend":
            return "Opkomend betekent dat het veld in beweging is en snel drukker kan worden."
        case "verzadigd":
            return "Verzadigd betekent dat het veld al vol zit en nieuwe ruimte schaars is."
        default:
            return "Deze opportunity laat zien hoeveel open speelruimte er nog is in dit onderzoeksdomein."
        }
    }

    private var domainText: String {
        item.domainLabel?.nilIfEmpty ?? item.domain
    }

    private var domainExplanation: String {
        let normalized = domainText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("health") {
            return "Dit domein gaat over gezondheid, zorg en medische besluitvorming waar signalen direct maatschappelijke impact kunnen hebben."
        }
        if normalized.contains("ai") {
            return "Dit domein gaat over AI-systemen, modellen en infrastructuur waar nieuwe gaps vaak snel strategisch relevant worden."
        }
        if normalized.contains("trust") {
            return "Dit domein gaat over vertrouwen, governance en controle: waar systemen veilig en begrensd moeten blijven."
        }
        return "Dit domein geeft aan in welk onderzoeksveld deze gap is waargenomen en waar de verbinding nog niet is getest."
    }

    private var opportunityColor: Color {
        opportunityColor(for: item.opportunityLabel ?? "")
    }

    private var propertyNameText: String? {
        let trimmed = item.propertyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    private var propertyDescriptionText: String? {
        let trimmed = item.propertyDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    private var propertyAxisColor: Color {
        propertyAxisColor(for: item.propertyAxis ?? "")
    }

    private var propertyAxisLabel: String {
        propertyAxisLabel(for: item.propertyAxis ?? "")
    }

    private var propertySectionBody: String {
        let description = propertyDescriptionText ?? "Geen extra beschrijving beschikbaar voor deze kenniseigenschap."
        return "\(description)\n\nAs: \(propertyAxisLabel)"
    }

    private func opportunityColor(for label: String) -> Color {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "vroeg stadium":
            return .consentGreen
        case "opkomend":
            return .orange
        case "verzadigd":
            return .gray
        default:
            return .jeevesSubtleText
        }
    }

    private func propertyAxisColor(for axis: String) -> Color {
        switch axis.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "movement":
            return Color(red: 0.16, green: 0.50, blue: 0.73)
        case "structure":
            return Color(red: 0.56, green: 0.27, blue: 0.68)
        case "potential":
            return Color(red: 0.15, green: 0.68, blue: 0.38)
        default:
            return .jeevesSubtleText
        }
    }

    private func propertyAxisLabel(for axis: String) -> String {
        switch axis.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "movement":
            return "Beweging"
        case "structure":
            return "Structuur"
        case "potential":
            return "Potentie"
        default:
            return "Onbekend"
        }
    }

    @ViewBuilder
    private func decisionButton(title: String, tint: Color, decision: String) -> some View {
        Button {
            pendingDecision = decision
            Task {
                let succeeded = await viewModel.decide(
                    item,
                    decision: decision,
                    reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                if succeeded {
                    dismiss()
                } else {
                    pendingDecision = nil
                }
            }
        } label: {
            HStack {
                if viewModel.activeDecisionId == item.id && pendingDecision == decision {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
                Text(title)
                    .font(.jeevesBody.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.activeDecisionId == item.id)
    }

    private func loadDecisionRoute() async {
        guard viewModel.canAttemptDecision(for: item) else {
            canDecide = false
            isResolvingDecision = false
            return
        }

        isResolvingDecision = true
        let target = await viewModel.resolveDecisionTarget(for: item)
        canDecide = target != nil
        isResolvingDecision = false
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

    @ViewBuilder
    private func detailSection(label: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.jeevesLogoRed)

            Text(title)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(Color.jeevesInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(body)
                .font(.jeevesBody)
                .foregroundStyle(Color.jeevesInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
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
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
