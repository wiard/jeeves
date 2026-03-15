import SwiftUI

struct InjectionSessionView: View {
    @Environment(GatewayManager.self) private var gateway
    @State private var vm: InjectionSessionViewModel
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    init(sessionId: String) {
        _vm = State(initialValue: InjectionSessionViewModel(sessionId: sessionId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        sessionHeader

                        if !vm.findings.isEmpty {
                            findingsSection
                        }

                        chatSection
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) {
                    if let last = vm.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            inputBar
        }
        .background(Color.jeevesMist)
        .navigationTitle("Injection Sessie")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load(gateway: gateway)
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("SESSIE")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesGold)

                Spacer()

                Text((vm.session?.status ?? "laden").uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
            }

            if let session = vm.session {
                Text(session.command.target.label)
                    .font(.headline)
                    .foregroundStyle(Color.jeevesInk)

                Text("Intent: \(session.command.intent) · Gestart door \(session.command.issuedBy)")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if vm.isLoading {
                ProgressView()
                    .tint(Color.jeevesGold)
            }

            if let err = vm.errorText {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Color.consentRed)
            }
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

    // MARK: - Findings

    private var findingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("FINDINGS")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesSky)

                Spacer()

                Text("\(vm.findings.count)")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
            }

            ForEach(vm.findings) { finding in
                findingCard(finding)
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

    private func findingCard(_ finding: InjectionFindingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: findingIcon(for: finding.kind))
                    .font(.caption)
                    .foregroundStyle(findingColor(for: finding.kind))

                Text(finding.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)

                Spacer()

                Text(finding.kind.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(findingColor(for: finding.kind))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(findingColor(for: finding.kind).opacity(0.12))
                    )
            }

            Text(finding.summary)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Text("Severity: \(finding.severity)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)

                Text("Score: \(finding.score, specifier: "%.1f")")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.jeevesCloud)
        )
    }

    // MARK: - Chat

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !vm.messages.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text("CONVERSATIE")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.jeevesMint)

                    Spacer()
                }
                .padding(.bottom, 4)
            }

            ForEach(vm.messages) { message in
                chatBubble(message)
                    .id(message.id)
            }

            if vm.isSending {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.jeevesMint)
                    Text("Robot denkt na...")
                        .font(.caption)
                        .foregroundStyle(Color.jeevesMutedText)
                }
                .padding(.leading, 4)
            }
        }
    }

    private func chatBubble(_ message: InjectionChatMessage) -> some View {
        HStack {
            if message.role == .operator_ { Spacer(minLength: 48) }

            VStack(alignment: message.role == .operator_ ? .trailing : .leading, spacing: 4) {
                Text(message.role == .operator_ ? "Operator" : "Robot")
                    .font(.caption2.monospaced())
                    .foregroundStyle(message.role == .operator_ ? Color.jeevesGold : Color.jeevesMint)

                Text(message.text)
                    .font(.jeevesBody)
                    .foregroundStyle(Color.jeevesInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(message.role == .operator_
                          ? Color.jeevesGold.opacity(0.08)
                          : Color.jeevesMint.opacity(0.08))
            )

            if message.role == .robot { Spacer(minLength: 48) }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("Vraag de robot...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .onSubmit { sendMessage() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.jeevesTitle)
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? Color.jeevesMutedText
                                         : Color.jeevesGold)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
                .accessibilityLabel("Verstuur vraag")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText
        inputText = ""
        Task {
            await vm.send(text, gateway: gateway)
        }
    }

    // MARK: - Helpers

    private func findingIcon(for kind: String) -> String {
        switch kind.lowercased() {
        case "gap":         return "exclamationmark.triangle"
        case "pattern":     return "waveform.path"
        case "opportunity": return "lightbulb"
        default:            return "doc.text.magnifyingglass"
        }
    }

    private func findingColor(for kind: String) -> Color {
        switch kind.lowercased() {
        case "gap":         return .consentOrange
        case "pattern":     return .jeevesSky
        case "opportunity": return .jeevesMint
        default:            return .jeevesGold
        }
    }
}
