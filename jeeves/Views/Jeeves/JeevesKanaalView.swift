import SwiftUI

struct JeevesKanaalView: View {
    @Environment(GatewayManager.self) private var gateway
    @StateObject private var viewModel = JeevesKanaalViewModel()
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcript
                composer
            }
            .navigationTitle("Kanaal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(Color(.systemGroupedBackground))
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    if viewModel.isSending {
                        HStack {
                            kanaalBubble(
                                text: "Jeeves verwerkt uw opdracht.",
                                isOperator: false
                            )
                            Spacer(minLength: 40)
                        }
                        .transition(.opacity)
                        .id("sending-indicator")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isSending) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Geef een opdracht aan JeevesKanaal", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .focused($composerFocused)
                .submitLabel(.send)
                .onSubmit {
                    send()
                }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(canSend ? Color.jeevesLogoRed : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend || viewModel.isSending)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func messageRow(_ message: JeevesKanaalMessage) -> some View {
        HStack(alignment: .bottom) {
            if message.author == .jeeves {
                kanaalBubble(text: message.text, isOperator: false)
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                kanaalBubble(text: message.text, isOperator: true)
            }
        }
    }

    private func kanaalBubble(text: String, isOperator: Bool) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(isOperator ? Color.white : Color.primary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isOperator
                        ? Color.jeevesLogoRed
                        : Color(.secondarySystemBackground)
                    )
            )
            .overlay(alignment: .bottomTrailing) {
                if !isOperator {
                    ProgressView()
                        .opacity(0)
                }
            }
    }

    private var canSend: Bool {
        !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend, !viewModel.isSending else { return }
        composerFocused = false
        Task {
            await viewModel.sendCurrentMessage(using: gateway)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = viewModel.messages.last?.id else { return }
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

#Preview {
    JeevesKanaalView()
        .environment(GatewayManager())
}
