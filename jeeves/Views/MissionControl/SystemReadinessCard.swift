import SwiftUI

struct SystemReadinessCard: View {
    let readiness: SystemReadinessSnapshot?
    let isLoading: Bool
    let errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("SYSTEM READY")
                    .font(.caption.monospaced())
                    .foregroundStyle(statusTint)

                Spacer()

                Text((readiness?.state ?? "booting").uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(statusTint.opacity(0.14)))
            }

            Text("Bootstrap prepares the machine. The research computer waits for your command.")
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            if isLoading && readiness == nil {
                ProgressView("System readiness laden...")
                    .font(.footnote)
            } else {
                Text(readiness?.summary ?? "Jeeves is waiting for the kernel to expose readiness.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let readiness {
                Text("Adapters: \(readiness.bootstrap.availableAdapterTypes.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)
                Text(readiness.bootstrap.checks.first(where: { $0.id == "clashd27_compute" })?.detail ?? "The research computer check is not available yet.")
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
                        .stroke(statusTint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var statusTint: Color {
        switch readiness?.state {
        case "ready":
            return .jeevesMint
        case "degraded":
            return .jeevesGold
        case "failed":
            return .red.opacity(0.8)
        default:
            return .jeevesSky
        }
    }
}
