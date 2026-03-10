import SwiftUI

struct InstrumentBackdrop: View {
    let colors: [Color]

    init(colors: [Color]) {
        self.colors = colors
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.white.opacity(0.32))
                .blur(radius: 80)
                .frame(width: 220, height: 220)
                .offset(x: -70, y: -90)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.jeevesGold.opacity(0.16))
                .blur(radius: 90)
                .frame(width: 240, height: 240)
                .offset(x: 70, y: 120)
        }
    }
}

struct InstrumentRoleHeader: View {
    let eyebrow: String
    let title: String
    let summary: String
    let accent: Color
    let metrics: [InstrumentRoleMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.jeevesLargeTitle)
                    .foregroundStyle(.primary)

                Text(summary)
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !metrics.isEmpty {
                ViewThatFits {
                    HStack(spacing: 10) {
                        ForEach(metrics) { metric in
                            InstrumentMetricPill(metric: metric, accent: accent)
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(metrics) { metric in
                            InstrumentMetricPill(metric: metric, accent: accent)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, y: 10)
    }
}

struct InstrumentRoleMetric: Identifiable {
    let id: String
    let label: String
    let value: String

    init(id: String? = nil, label: String, value: String) {
        self.id = id ?? label
        self.label = label
        self.value = value
    }
}

private struct InstrumentMetricPill: View {
    let metric: InstrumentRoleMetric
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            Text(metric.value)
                .font(.jeevesMetric)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
    }
}

private struct CalmEntrance: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 18)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func calmAppear(delay: Double = 0) -> some View {
        modifier(CalmEntrance(delay: delay))
    }
}
