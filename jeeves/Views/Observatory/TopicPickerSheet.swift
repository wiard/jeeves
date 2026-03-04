import SwiftUI

struct TopicPickerSheet: View {
    let topics: [TopicItem]
    let selectedTopicId: String?
    let onSelect: (TopicItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var category: String = "All"

    private var categories: [String] {
        let values = Set(topics.map(\.category))
        return ["All"] + values.sorted()
    }

    private var filteredTopics: [TopicItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return topics
            .filter { category == "All" || $0.category == category }
            .filter { item in
                if trimmed.isEmpty { return true }
                return item.title.localizedCaseInsensitiveContains(trimmed) || item.id.localizedCaseInsensitiveContains(trimmed)
            }
            .sorted {
                if $0.category != $1.category { return $0.category < $1.category }
                return $0.title < $1.title
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search topic", text: $query)
                }

                Section("Categories") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { item in
                                Button(item) {
                                    category = item
                                }
                                .buttonStyle(.bordered)
                                .tint(category == item ? .jeevesGold : .secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Topics") {
                    if filteredTopics.isEmpty {
                        Text("Unavailable")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredTopics, id: \.id) { item in
                            topicRow(item)
                        }
                    }
                }
            }
            .navigationTitle("Pick Topic")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    @ViewBuilder
    private func topicRow(_ item: TopicItem) -> some View {
        Button {
            onSelect(item)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                    Text(item.category)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if item.id == selectedTopicId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.jeevesGold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
