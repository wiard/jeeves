import SwiftUI

struct Clashd27ComputerCard: View {
    let computer: Clashd27ComputerSnapshot?
    let isLoading: Bool
    let errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("RESEARCH COMPUTER")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMint)

                Spacer()

                Text((computer?.state ?? "idle").uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.jeevesMint.opacity(0.14)))
            }

            Text("C1 controls, C2 computes, the cube explores, and residue memory retains what mattered.")
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            if isLoading && computer == nil {
                ProgressView("Research computer laden...")
                    .font(.footnote)
            } else {
                Text(computer?.lastSummary ?? "The research computer is waiting for a governed command.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let computer {
                Text("Controller: \(computer.controllerState.replacingOccurrences(of: "_", with: " "))")
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)

                Text("ALU: \(computer.aluActivity.replacingOccurrences(of: "_", with: " "))")
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)

                Text("Exploring models: peak \(computer.cubeState.peakActiveCellCount) active cells, \(computer.cubeState.taskQueue.count) queued tasks, \(computer.cubeState.results.count) completed tasks.")
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Merged findings: \(computer.mergedFindingCount)")
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)

                Text("Cube: \(computer.cubeState.summary)")
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Residue memory: \(computer.residueMemory.summary)")
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.jeevesMint.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
