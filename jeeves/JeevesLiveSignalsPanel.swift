import SwiftUI

struct JeevesLiveSignalsPanel: View {
    let runtime: SignalsRuntimeSnapshot?
    let operatorMemory: SystemOperatorMemorySnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasGovernedData {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        metric("Sources", "\(activeSourceCount)")
                        metric("Signals", "\(totalSignals)")
                    }

                    HStack(spacing: 10) {
                        metric("Research", "\(researchSignalCount)")
                        metric("Memory", "\(memoryTrendCount)")
                    }
                }

                if !sourceRows.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Governed Sources")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.jeevesMutedText)

                        ForEach(sourceRows) { source in
                            sourceRow(source)
                        }
                    }
                }

                if !recentSignals.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Governed Signals")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.jeevesMutedText)

                        ForEach(recentSignals) { signal in
                            signalRow(signal)
                        }
                    }
                }

                if !memoryRows.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Operator Memory")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.jeevesMutedText)

                        ForEach(memoryRows) { row in
                            memoryRow(row)
                        }
                    }
                }
            } else {
                Text("Governed live signal telemetry will appear here after the gateway reports discovery state.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
            }
        }
    }

    private var hasGovernedData: Bool {
        runtime != nil || operatorMemory != nil
    }

    private var activeSourceCount: Int {
        runtime?.activeSourceCount ?? sourceRows.count
    }

    private var totalSignals: Int {
        runtime?.totalSignals ?? recentSignals.count
    }

    private var researchSignalCount: Int {
        runtime?.researchLane?.signalCount24h ?? 0
    }

    private var memoryTrendCount: Int {
        memoryRows.count
    }

    private var sourceRows: [GovernedSourceRow] {
        if let research = runtime?.researchLane,
           !research.sourceBreakdown.isEmpty {
            return Array(research.sourceBreakdown.prefix(6)).map { source in
                GovernedSourceRow(
                    id: source.source,
                    title: humanize(source.source),
                    detail: "\(source.signalCount) research signal\(source.signalCount == 1 ? "" : "s") in the last 24 hours.",
                    badge: "\(source.signalCount)",
                    count: source.signalCount
                )
            }
        }

        guard let runtime else { return [] }

        let grouped = Dictionary(grouping: runtime.lastSignals) { signal in
            let rawSource = signal.sourceId?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (rawSource?.isEmpty == false) ? rawSource! : "governed gateway"
        }

        return grouped
            .map { source, signals in
                GovernedSourceRow(
                    id: source,
                    title: humanize(source),
                    detail: "\(signals.count) recent governed signal\(signals.count == 1 ? "" : "s").",
                    badge: "\(signals.count)",
                    count: signals.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.title < rhs.title
                }
                return lhs.count > rhs.count
            }
    }

    private var recentSignals: [SignalsRuntimeSignal] {
        Array((runtime?.lastSignals ?? []).prefix(4))
    }

    private var memoryRows: [GovernedMemoryRow] {
        guard let operatorMemory else { return [] }

        var rows: [GovernedMemoryRow] = [
            GovernedMemoryRow(
                id: "focus",
                title: "Remembered focus",
                detail: humanize(operatorMemory.operatorFocusMemory.strongestFocus),
                note: operatorMemory.operatorFocusMemory.explanation
            )
        ]

        if let pattern = operatorMemory.patternMemory.first {
            rows.append(
                GovernedMemoryRow(
                    id: "pattern-\(pattern.id)",
                    title: "Pattern memory",
                    detail: "\(humanize(pattern.patternType)) · \(pattern.recentApprovals) approvals · \(pattern.recurrence) recurrences",
                    note: pattern.explanation
                )
            )
        }

        if let knowledge = operatorMemory.knowledgeMemory.first {
            rows.append(
                GovernedMemoryRow(
                    id: "knowledge-\(knowledge.id)",
                    title: "Knowledge memory",
                    detail: "\(humanize(knowledge.knowledgeKind)) · \(knowledge.recentObjects) objects · \(knowledge.linkedApprovals) linked approvals",
                    note: knowledge.explanation
                )
            )
        }

        return rows
    }

    private func sourceRow(_ source: GovernedSourceRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)

                Text(source.detail)
                    .font(.caption)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(source.badge)
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesSky)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.jeevesSky.opacity(0.12))
                )
        }
    }

    private func signalRow(_ signal: SignalsRuntimeSignal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(humanize(signal.sourceId ?? "governed gateway"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)

                Text(signal.summary ?? "Recent discovery signal visible in the governed stream.")
                    .font(.caption2)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(shortTimestamp(signal.detectedAtIso))
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesMutedText)
        }
    }

    private func memoryRow(_ row: GovernedMemoryRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.title.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesMutedText)

            Text(row.detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.jeevesInk)

            Text(row.note)
                .font(.caption2)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesMutedText)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.jeevesInk)

            Text(metricStatusLine(label: label, value: value))
                .font(.caption2)
                .foregroundStyle(Color.jeevesSubtleText)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.jeevesCloud.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.jeevesLine.opacity(0.6), lineWidth: 1)
        )
    }

    private func metricStatusLine(label: String, value: String) -> String {
        switch label {
        case "Sources":
            return "\(value) visible"
        case "Signals":
            return "current intake"
        case "Research":
            return "24h discovery"
        case "Memory":
            return "stable trends"
        default:
            return ""
        }
    }

    private func shortTimestamp(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "unknown"
        }
        if value.count <= 16 {
            return value
        }
        return String(value.prefix(16))
    }

    private func humanize(_ value: String) -> String {
        value
            .split(whereSeparator: { $0 == " " || $0 == "_" || $0 == "-" })
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

private struct GovernedSourceRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let badge: String
    let count: Int
}

private struct GovernedMemoryRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let note: String
}
