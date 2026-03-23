import SwiftUI

struct ChipLearningSummarySection: View {
    let summary: ChipLearningViewModel.SummaryCard
    let runs: [ChipRun]
    let outcomes: [ChipOutcome]
    let hypotheses: [ChipHypothesis]
    let runChanges: [ChipLearningViewModel.RunChange]
    let actionBanner: ChipLearningViewModel.ActionBanner?
    let isLoading: Bool
    let errorText: String?

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Chip Learning",
            title: "Wat recente runs ons leren",
            subtitle: "Jeeves vat chip-runs, outcomes en hypotheses samen tot een rustige operatorlaag. Dit verandert niets aan de authority boundary.",
            accent: .jeevesMint,
            metric: summary.updatedText
        ) {
            if isLoading && runs.isEmpty && outcomes.isEmpty && hypotheses.isEmpty {
                ProgressView("Chip learning wordt geladen…")
                    .font(.jeevesBody)
            } else if runs.isEmpty && outcomes.isEmpty && hypotheses.isEmpty {
                Text(errorText ?? "Chip learning is nog niet zichtbaar vanaf deze gateway.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard

                    if let actionBanner {
                        actionBannerCard(actionBanner)
                    }

                    if !runChanges.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("RECENTE RUNVERSCHILLEN", tint: .jeevesMint)

                            ForEach(runChanges) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(item.title)
                                            .font(.jeevesBody.weight(.semibold))
                                            .foregroundStyle(Color.jeevesInk)

                                        Spacer(minLength: 8)

                                        chipMetaPill(item.badge, tint: toneColor(item.tone))
                                    }

                                    Text(item.summary)
                                        .font(.jeevesCaption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(item.isHighlighted ? Color.jeevesMint.opacity(0.08) : Color(.secondarySystemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(item.isHighlighted ? Color.jeevesMint.opacity(0.22) : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }

                    if !outcomes.isEmpty || !hypotheses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("LEARNING CONTEXT", tint: .jeevesSky)

                            if !outcomes.isEmpty {
                                digestCard(
                                    title: "Recente outcomes",
                                    rows: outcomes.prefix(3).map { outcome in
                                        let state = outcome.blocking ? "blokkerend" : "niet blokkerend"
                                        return "\(outcome.pathKey) · \(humanizeClassification(outcome.classification)) · \(state)"
                                    }
                                )
                            }

                            if !hypotheses.isEmpty {
                                digestCard(
                                    title: "Recente hypotheses",
                                    rows: hypotheses.prefix(3).map { hypothesis in
                                        let path = hypothesis.pathKey?.nilIfEmpty ?? "algemeen pad"
                                        return "\(path) · \(hypothesis.suggestedAction)"
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary.headline)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(Color.jeevesInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(summary.supportingLine)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                chipMetaPill(summary.runCountText, tint: .jeevesMint)
                chipMetaPill(summary.blockingText, tint: .consentOrange)
                chipMetaPill(summary.hypothesisText, tint: .jeevesSky)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.jeevesPanelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.jeevesMint.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func digestCard(title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMutedText)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Text(row)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func actionBannerCard(_ banner: ChipLearningViewModel.ActionBanner) -> some View {
        let tint = bannerColor(banner.tone)

        return VStack(alignment: .leading, spacing: 6) {
            Text(banner.title)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(Color.jeevesInk)

            Text(banner.detail)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func sectionLabel(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesMonoSmall)
            .foregroundStyle(tint)
    }

    private func chipMetaPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesMonoSmall)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private func toneColor(_ tone: ChipLearningViewModel.RunChange.Tone) -> Color {
        switch tone {
        case .improved:
            return .consentGreen
        case .steady:
            return .jeevesSky
        case .urgent:
            return .consentOrange
        }
    }

    private func bannerColor(_ tone: ChipLearningViewModel.ActionBanner.Tone) -> Color {
        switch tone {
        case .pending:
            return .consentOrange
        case .success:
            return .consentGreen
        case .failed:
            return .consentRed
        }
    }

    private func humanizeClassification(_ value: String) -> String {
        switch value.lowercased() {
        case "setup-violation":
            return "setup"
        case "hold-violation":
            return "hold"
        default:
            return value.replacingOccurrences(of: "-", with: " ")
        }
    }
}

struct ChipRecommendedFixesSection: View {
    let recommendations: [ChipLearningViewModel.Recommendation]
    let actionState: (ChipLearningViewModel.Recommendation) -> ChipLearningViewModel.ActionState?
    let onTryRecommendation: (ChipLearningViewModel.Recommendation) -> Void
    let isLoading: Bool
    let errorText: String?

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Recommended Fixes",
            title: "Wat het systeem hierna zou proberen",
            subtitle: "Dit is operatoradvies, geen autonome optimalisatie. Waar hypotheses ontbreken, markeert Jeeves het advies expliciet als heuristisch.",
            accent: .consentOrange,
            metric: recommendations.isEmpty ? "Quiet" : "\(recommendations.count) zichtbaar"
        ) {
            if isLoading && recommendations.isEmpty {
                ProgressView("Aanbevelingen worden opgebouwd…")
                    .font(.jeevesBody)
            } else if recommendations.isEmpty {
                Text(errorText ?? "Er is nog geen chipadvies zichtbaar. Zodra de gateway outcomes en hypotheses publiceert, vat Jeeves ze hier samen.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recommendations.prefix(5)) { item in
                        recommendationCard(item)
                    }
                }
            }
        }
    }

    private func recommendationCard(_ item: ChipLearningViewModel.Recommendation) -> some View {
        let state = actionState(item)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.recommendationLabel)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)

                Spacer(minLength: 8)

                chipMetaPill(item.severityLabel, tint: item.isBlocking ? .consentOrange : .jeevesSky)
            }

            HStack(spacing: 8) {
                chipMetaPill(item.pathKey, tint: .jeevesMint)
                chipMetaPill(item.classificationLabel, tint: .jeevesSky)
                if item.usesHeuristic {
                    chipMetaPill("Heuristiek", tint: .jeevesGold)
                }
            }

            recommendationRow("Volgende stap", item.suggestedAction)
            recommendationRow("Waarom", item.rationale)

            if let learningContext = item.learningContext?.nilIfEmpty {
                recommendationRow("Leercontext", learningContext)
            }

            HStack(alignment: .center, spacing: 10) {
                Button {
                    onTryRecommendation(item)
                } label: {
                    HStack(spacing: 8) {
                        if state?.phase == .sending {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Probeer dit")
                            .font(.jeevesBody.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(item.isBlocking ? .consentOrange : .jeevesSky)
                .disabled(state?.phase == .sending || state?.phase == .pending)

                if let state {
                    Text(state.message)
                        .font(.jeevesCaption)
                        .foregroundStyle(statusColor(state.phase))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.jeevesPanelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke((item.isBlocking ? Color.consentOrange : Color.jeevesSky).opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func recommendationRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMutedText)

            Text(value)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chipMetaPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesMonoSmall)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private func statusColor(_ phase: ChipLearningViewModel.ActionState.Phase) -> Color {
        switch phase {
        case .sending:
            return .jeevesSky
        case .pending:
            return .consentOrange
        case .success:
            return .consentGreen
        case .failed:
            return .consentRed
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
