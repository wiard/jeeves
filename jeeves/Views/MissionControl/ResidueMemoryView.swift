import SwiftUI

struct ResidueMemoryView: View {
    let entries: [TuringResidueMemoryEntrySnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("SYSTEM MEMORY")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesSky)

                Spacer()

                Text("\(entries.count) ENTRY\(entries.count == 1 ? "" : "IES")")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
            }

            Text(entries.isEmpty
                 ? "No important outcome has been retained in system memory yet."
                 : "Important outcomes remain in system memory because this research task produced a meaningful consequence.")
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            if entries.isEmpty {
                Text("System memory is updated only when a research task produces a meaningful consequence such as a confirmed pattern, validated hypothesis, structural conflict, actionable opportunity, or operator decision.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(entries.prefix(3)) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.consequence)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.jeevesInk)
                        Text(entry.meaning)
                            .font(.caption)
                            .foregroundStyle(Color.jeevesSubtleText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Address: \(entry.memoryAddress)")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.jeevesMutedText)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.jeevesSky.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
