import SwiftUI

struct GuideEntryCard: View {
    let store: AppStore
    var body: some View {
        Button {
            store.guideTopic = "start"
            store.route = "guide"
        } label: {
            HStack(spacing: 16) {
                FrondaMascot(size: 60)
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.snapshot.runs.isEmpty ? "Vamos preparar seu espaço?" : "Uma ajuda na hora certa.")
                        .font(.headline).foregroundStyle(.primary)
                    Text("Primeiros passos, contexto do provider e escolhas de modelo.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Label("Abrir guia", systemImage: "arrow.up.right").font(.callout.weight(.medium))
                    .foregroundStyle(FrondaTheme.accent)
            }.padding(18).background(FrondaTheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}
