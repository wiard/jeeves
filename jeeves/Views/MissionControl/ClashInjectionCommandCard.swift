import SwiftUI

struct ClashInjectionCommandCard: View {
    let readiness: SystemReadinessSnapshot?
    let targets: [InjectionTargetOption]
    @Binding var selectedTargetId: String?
    @Binding var selectedIntent: String
    @Binding var notes: String
    let isStarting: Bool
    let onStart: () -> Void
    let onStartDemo: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("RESEARCH TASKS")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesSky)

                Spacer()

                Text("COMMAND")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
            }

            Text("Start a read-only research task in a repository, API, or service environment.")
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            Text("Investigations stay bounded and read-only in Phase 1. Typical targets are repositories, APIs, and service environments.")
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Target", selection: $selectedTargetId) {
                ForEach(targets.filter { $0.status == "ready" }) { target in
                    Text(target.label).tag(Optional(target.id))
                }
            }
            .pickerStyle(.menu)

            Picker("Intent", selection: $selectedIntent) {
                Text("Inspect").tag("inspect")
                Text("Investigate").tag("investigate")
                Text("Analyze").tag("analyze")
            }
            .pickerStyle(.segmented)

            TextField("Optional notes for this investigation", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Button(action: onStart) {
                if isStarting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(buttonLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.jeevesSky)
            .disabled(!canStart)

            if let onStartDemo, targets.contains(where: { $0.mode == "demo" && $0.status == "ready" }) {
                Button(action: onStartDemo) {
                    Text("Run demo research task")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isStarting || readiness?.commandInitiationReady != true)
            }

            Text(readiness?.commandInitiationReady == true
                 ? "The system is ready. Starting this command will create a bounded research task."
                 : "Bootstrap must be ready before an investigation can begin.")
                .font(.caption)
                .foregroundStyle(Color.jeevesMutedText)
                .fixedSize(horizontal: false, vertical: true)
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

    private var canStart: Bool {
        readiness?.commandInitiationReady == true && selectedTargetId != nil && !isStarting
    }

    private var buttonLabel: String {
        if let target = targets.first(where: { $0.id == selectedTargetId }) {
            return "Start research task: \(target.label)"
        }
        return "Start research task"
    }
}
