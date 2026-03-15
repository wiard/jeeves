import SwiftUI

struct ResidueMemoryView: View {
    let entries: [TuringResidueMemoryEntrySnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("TURING RESIDUE MEMORY")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesSky)

                Spacer()

                Text("\(entries.count) ENTRY\(entries.count == 1 ? "" : "IES")")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
            }

            Text(entries.isEmpty
                 ? "No meaningful consequence has been retained in memory yet."
                 : "Meaningful consequences now remain in memory because this investigation produced residue.")
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            if entries.isEmpty {
                Text("Residue is only written when the investigation produces a meaningful consequence.")
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
