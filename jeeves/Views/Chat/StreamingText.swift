import SwiftUI

struct StreamingText: View {
    let text: String
    @State private var showCursor = true

    var body: some View {
        HStack {
            HStack(spacing: 0) {
                Text(text)
                    .font(.jeevesBody)
                if showCursor {
                    Text("|")
                        .font(.jeevesBody)
                        .foregroundStyle(.jeevesGold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                showCursor.toggle()
            }
        }
    }
}
