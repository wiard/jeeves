import SwiftUI

struct InvestigationCycleView: View {
    let session: InjectionSessionSnapshot?
    let computer: Clashd27ComputerSnapshot?
    let cycle: InjectionCycleSnapshot?
    let findings: [InjectionFindingSnapshot]
    let consequences: [InjectionConsequenceSnapshot]
    let residue: [InjectionResidueSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("INVESTIGATION CYCLE")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesGold)

                Spacer()

                Text((session?.status ?? "idle").uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
            }

            Text(sessionHeadline)
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            if let computer {
                Text("C1 is \(computer.controllerState.replacingOccurrences(of: "_", with: " ")). \(computer.cubeState.summary)")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("The cube queued \(computer.cubeState.taskQueue.count) tasks and produced \(computer.cubeState.results.count) intermediate result\(computer.cubeState.results.count == 1 ? "" : "s").")
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)
                    .fixedSize(horizontal: false, vertical: true)

                if computer.cubeState.peakActiveCellCount > 1 {
                    Text("Exploring models in parallel across \(computer.cubeState.peakActiveCellCount) cube cells.")
                        .font(.caption)
                        .foregroundStyle(Color.jeevesGold)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let cycle {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(cycle.events.suffix(6)) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.state.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.jeevesGold)
                            Text(event.detail)
                                .font(.footnote)
                                .foregroundStyle(Color.jeevesSubtleText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text("No active investigation yet. When you issue a command, the cycle will appear here.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
            }

            if !findings.isEmpty {
                Text("Findings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)

                ForEach(findings.prefix(3)) { finding in
                    Text("\(finding.title) · \(finding.severity)")
                        .font(.footnote)
                        .foregroundStyle(Color.jeevesInk)
                }
            }

            if !consequences.isEmpty {
                Text("Consequence")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)

                Text(consequences[0].summary)
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(residue.isEmpty
                 ? "No meaningful consequence yet, so no residue has been emitted."
                 : "Meaningful consequence was recorded, so residue now remains from this investigation.")
                .font(.caption)
                .foregroundStyle(residue.isEmpty ? Color.jeevesMutedText : Color.jeevesGold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.jeevesGold.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var sessionHeadline: String {
        guard let session else {
            return "The system is standing by for a command-driven investigation."
        }
        return "\(session.command.target.label) is being examined because the operator started a CLASH Injection session."
    }
}
