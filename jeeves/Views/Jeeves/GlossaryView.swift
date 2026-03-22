import SwiftUI

struct GlossaryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    glossarySection(
                        letter: "G",
                        tint: Color.jeevesLogoRed,
                        title: "Gap",
                        body: "Een gap is een ontbrekend experiment. Twee kennisdomeinen raken elkaar — maar niemand heeft de verbinding nog getest. CLASHD27 detecteert die verbinding. Jij besluit of het de moeite waard is."
                    )

                    glossarySection(
                        letter: "O",
                        tint: .consentGreen,
                        title: "Opportunity",
                        body: "Een opportunity zegt hoe open het speelveld nog is. Vroeg stadium betekent: weinig concurrentie, veel ruimte. Verzadigd betekent: het veld is vol."
                    )

                    glossarySection(
                        letter: "J",
                        tint: Color(red: 0.16, green: 0.50, blue: 0.73),
                        title: "Jouw beslissing",
                        body: "Niets in dit systeem gebeurt zonder jouw goedkeuring. Jeeves observeert. Jij beslist. Dat is de enige regel."
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meer op openclashd.com")
                            .font(.caption)
                            .foregroundStyle(Color.jeevesSubtleText)

                        Link("openclashd.com", destination: URL(string: "https://openclashd.com")!)
                            .font(.jeevesBody.weight(.semibold))
                            .foregroundStyle(Color.jeevesLogoRed)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.jeevesMist.ignoresSafeArea())
            .navigationTitle("Wat Jeeves voor jou doet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") {
                        dismiss()
                    }
                    .foregroundStyle(Color.jeevesLogoRed)
                }
            }
        }
    }

    private func glossarySection(letter: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 46, height: 46)

                Text(letter)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.jeevesBody.weight(.bold))
                    .foregroundStyle(Color.jeevesInk)

                Text(body)
                    .font(.jeevesBody)
                    .foregroundStyle(Color.jeevesInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
    }
}
