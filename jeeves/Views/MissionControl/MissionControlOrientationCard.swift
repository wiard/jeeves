import SwiftUI

struct MissionControlOrientationCard: View {
    let connectionLine: String
    let systemLine: String
    let nextStepLine: String
    let primaryActions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("START HERE")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesSky)

                Spacer()

                Text("YOUR GUIDE")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
            }

            Text("Monitor a governed AI system, review decisions, and start investigations to find patterns, gaps, and opportunities.")
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            Text("Use this screen to follow live system state and investigate targets such as repositories, APIs, and services.")
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            actionPills

            orientationRow(label: "Connection", value: connectionLine)
            orientationRow(label: "System", value: systemLine)
            orientationRow(label: "Next step", value: nextStepLine)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.jeevesSky.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func orientationRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesMutedText)

            Text(value)
                .font(.footnote)
                .foregroundStyle(Color.jeevesInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionPills: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT YOU CAN DO HERE")
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesMutedText)

            FlexiblePillStack(items: primaryActions)
        }
    }
}

private struct FlexiblePillStack: View {
    let items: [String]

    var body: some View {
        ViewThatFits {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    pill(item)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    pill(item)
                }
            }
        }
    }

    private func pill(_ item: String) -> some View {
        Text(item)
            .font(.caption)
            .foregroundStyle(Color.jeevesInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.jeevesSky.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(Color.jeevesSky.opacity(0.14), lineWidth: 1)
            )
    }
}
