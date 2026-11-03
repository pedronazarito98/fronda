import SwiftUI

struct RunFollowupHistory: View {
    let items: [RunFollowupHistoryItem]
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 18) {
                if items.isEmpty {
                    Text("Nenhum ciclo registrado nesta tarefa.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: item.appearance.symbol)
                            .foregroundStyle(item.appearance.color)
                            .padding(.top, 2).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.caption.weight(.semibold))
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            ForEach(Array(item.checks.enumerated()), id: \.offset) { _, check in
                                Text(check).font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Histórico dos ciclos").font(.callout.weight(.medium))
        }
        .accessibilityIdentifier("followup.cycle-history")
    }
}
