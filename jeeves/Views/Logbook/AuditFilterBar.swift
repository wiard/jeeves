import SwiftUI

struct AuditFilterBar: View {
    @Binding var selectedPeriod: AuditPeriod
    @Binding var selectedFilter: AuditFilter

    var body: some View {
        VStack(spacing: 8) {
            // Period filter
            Picker("Periode", selection: $selectedPeriod) {
                ForEach(AuditPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            // Type filter
            Picker("Filter", selection: $selectedFilter) {
                ForEach(AuditFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
