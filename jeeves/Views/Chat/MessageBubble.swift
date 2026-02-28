import SwiftUI

struct MessageBubble: View {
    let text: String
    let sender: MessageSender
    let timestamp: Date

    private var isUser: Bool { sender == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .font(sender == .jeeves ? .jeevesBody : .body)
                    .foregroundStyle(isUser ? .white : .primary)

                Text(timestamp, style: .time)
                    .font(.jeevesCaption)
                    .foregroundStyle(isUser ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if isUser {
            return AnyShapeStyle(Color.jeevesGold)
        } else if sender == .system {
            return AnyShapeStyle(Color.secondary.opacity(0.15))
        } else {
            return AnyShapeStyle(Color(.systemGray5))
        }
    }
}
