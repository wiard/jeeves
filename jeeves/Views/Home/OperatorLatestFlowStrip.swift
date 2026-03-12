import SwiftUI

struct OperatorLatestFlowStrip: View {
    let items: [OperatorOverviewSnapshot.LoopStage]
    @State private var pulseActive = false

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "System Loop",
            title: "Discovery -> Proposal -> Approval -> Bounded Action -> Knowledge",
            subtitle: "The highlighted stage is where the pipeline is currently active.",
            accent: .blue
        ) {
            ViewThatFits {
                HStack(alignment: .center, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        loopCell(for: item)

                        if index < items.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.jeevesMonoSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        loopCell(for: item)
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 140, height: 140)
                .blur(radius: 46)
                .offset(x: -28, y: -32)
                .allowsHitTesting(false)
        }
        .onAppear {
            guard !pulseActive else { return }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                pulseActive = true
            }
        }
    }

    private func loopCell(for item: OperatorOverviewSnapshot.LoopStage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.stage.title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(item.isActive ? Color.white.opacity(0.96) : Color.secondary)

            Text(item.metric)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(item.isActive ? Color.white.opacity(0.98) : monoTint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: item.isActive
                            ? [accentColor(for: item).opacity(0.34), Color.black.opacity(0.16)]
                            : [accentColor(for: item).opacity(0.12), Color.black.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor(for: item).opacity(item.isActive ? 0.42 : 0.16), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(accentColor(for: item))
                .frame(
                    width: item.isActive ? 11 + (pulseActive ? 2 : 0) : 8,
                    height: item.isActive ? 11 + (pulseActive ? 2 : 0) : 8
                )
                .shadow(color: accentColor(for: item).opacity(item.isActive ? 0.45 : 0.16), radius: item.isActive ? 8 : 3)
                .padding(10)
        }
        .shadow(color: accentColor(for: item).opacity(item.isActive ? 0.22 : 0.08), radius: item.isActive ? 10 : 4, y: 3)
        .animation(.easeInOut(duration: 0.18), value: item.isActive)
    }

    private func accentColor(for item: OperatorOverviewSnapshot.LoopStage) -> Color {
        switch item.stage {
        case .discovery:
            return .blue
        case .proposal:
            return .blue
        case .approval:
            return .orange
        case .action:
            return item.tone == .watch ? .red : .blue
        case .knowledge:
            return .green
        }
    }

    private var monoTint: Color {
        Color(red: 147 / 255.0, green: 197 / 255.0, blue: 253 / 255.0)
    }
}
