import SwiftUI

struct SettingsView: View {
    @Environment(GatewayManager.self) private var gateway

    var body: some View {
        NavigationStack {
            List {
                ConnectionSettings()
                SecuritySettings()
                displaySection
                infoSection
            }
            .navigationTitle("Instellingen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }

    private var displaySection: some View {
        Section("Weergave") {
            HStack {
                Text("Taal")
                Spacer()
                Text("Nederlands")
                    .foregroundStyle(.secondary)
            }

            Toggle("Spraak input", isOn: .constant(true))

            Toggle("Haptic feedback", isOn: .constant(true))

            HStack {
                Text("Donkere modus")
                Spacer()
                Text("Automatisch")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var infoSection: some View {
        Section("Info") {
            HStack {
                Text("Versie")
                Spacer()
                Text("Jeeves v0.1.0")
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Gateway")
                Spacer()
                Text("OpenClashd v2")
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }

            Text("\"Not Jarvis. Jeeves.\"")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .italic()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        }
    }
}
