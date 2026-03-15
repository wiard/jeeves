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
                .fill(Color.jeevesSky.opacity(0.14))
                .blur(radius: 100)
                .frame(width: 280, height: 280)
                .offset(x: -72, y: -94)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.jeevesMint.opacity(0.16))
                .blur(radius: 100)
                .frame(width: 260, height: 260)
                .offset(x: 76, y: 118)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.jeevesGold.opacity(0.08))
                .blur(radius: 90)
                .frame(width: 200, height: 200)
                .offset(x: 50, y: -40)
        }
        .overlay(alignment: .center) {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(Color.jeevesPanel.opacity(0.56))
                .blur(radius: 120)
                .padding(.horizontal, 18)
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
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.jeevesPanelStrong.opacity(0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                // Subtle accent glow at top-left
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.06), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.10), radius: 20, y: 10)
    }
}

struct InstrumentSectionPanel<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    let metric: String?
    let content: Content

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        accent: Color,
        metric: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.metric = metric
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased())
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(accent)

                    Text(title)
                        .font(.jeevesHeadline)

                    Text(subtitle)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if let metric, !metric.isEmpty {
                    Text(metric)
                        .font(.jeevesMetric)
                        .foregroundStyle(accent)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .briefingPanel()
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
                .fill(
                    LinearGradient(
                        colors: [Color.white, accent.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.16), lineWidth: 1)
                )
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
                withAnimation(.easeOut(duration: 0.45).delay(delay)) {
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
