import HarnessDomain
import SwiftUI

struct RunFollowupCriteria: View {
    let criteria: [Criterion]
    let limits: [String]
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 14) {
                if criteria.isEmpty {
                    Text("Nenhum critério de conclusão registrado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(criteria) { criterion in
                    criterionRow(criterion)
                }
                if !criteria.isEmpty { Divider() }
                Text("Limites").font(.caption.weight(.semibold))
                ForEach(Array(limits.enumerated()), id: \.offset) { _, limit in
                    Text(limit).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Critérios e limites").font(.callout.weight(.medium))
        }
        .accessibilityIdentifier("followup.criteria-limits")
    }

    private func criterionRow(_ criterion: Criterion) -> some View {
        let confirmed = RunFollowupEvidence.criterionIsConfirmed(criterion)
        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: confirmed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(confirmed ? FrondaTheme.success : FrondaTheme.textMuted)
                .padding(.top, 2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.text).font(.caption).textSelection(.enabled)
                Text(confirmed ? "Confirmado com evidência" : "Aguarda evidência")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
