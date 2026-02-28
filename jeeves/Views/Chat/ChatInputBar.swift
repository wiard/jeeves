import SwiftUI
import Speech

struct ChatInputBar: View {
    let onSend: (String) -> Void

    @State private var inputText = ""
    @State private var isRecording = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("Typ een bericht...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .onSubmit(send)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                if inputText.isEmpty {
                    Button(action: toggleSpeech) {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.title3)
                            .foregroundStyle(isRecording ? .consentRed : .jeevesGold)
                    }
                    .accessibilityLabel(isRecording ? "Stop spraakherkenning" : "Start spraakherkenning")
                } else {
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.jeevesGold)
                    }
                    .accessibilityLabel("Verstuur bericht")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        onSend(text)
    }

    private func toggleSpeech() {
        // Speech recognition placeholder
        // Real implementation would use SFSpeechRecognizer
        isRecording.toggle()
    }
}
