import HarnessDomain
import SwiftUI

struct GuideJourney: View {
    let store: AppStore
    let select: (String) -> Void
    private let milestones: [(String, String, String, String)] = [
        ("providers", "Conecte", "Seu executor", "terminal"),
        ("context", "Traga", "Seu contexto", "leaf"),
        ("first-task", "Prepare", "Seu projeto", "folder"),
        ("models", "Comece", "Sua tarefa", "sparkles"),
    ]
    private var completion: [Bool] {
        [
            store.snapshot.providers.contains { $0.state == "AVAILABLE" },
            store.snapshot.preferences.extensions?.isEmpty == false,
            !store.snapshot.projects.isEmpty, !store.snapshot.runs.isEmpty,
        ]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Seu percurso", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.headline)
                Spacer()
                Text("\(completion.filter { $0 }.count) de 4 preparados").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                    Button {
                        select(milestone.0)
                    } label: {
                        VStack(spacing: 9) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(systemName: milestone.3)
                                    .font(.system(size: 25, weight: .light))
                                    .foregroundStyle(FrondaTheme.accent)
                                    .frame(width: 64, height: 64)
                                    .background(
                                        FrondaTheme.accent.opacity(completion[index] ? 0.15 : 0.05), in: Circle()
                                    )
                                    .overlay(
                                        Circle().strokeBorder(
                                            FrondaTheme.accent.opacity(0.25),
                                            style: StrokeStyle(lineWidth: 1, dash: completion[index] ? [] : [3, 4])))
                                if completion[index] {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(FrondaTheme.success)
                                        .background(FrondaTheme.surface, in: Circle())
                                }
                            }
                            Text(milestone.1).font(.headline)
                            Text(milestone.2).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(
                        "\(milestone.1) · \(milestone.2)\(completion[index] ? " · preparado" : "")")
                    if index < milestones.count - 1 {
                        Image(systemName: "arrow.right").font(.system(size: 13, weight: .light))
                            .foregroundStyle(FrondaTheme.accent.opacity(0.5)).padding(.top, 26)
                    }
                }
            }
            Text("O percurso acompanha suas conexões e tarefas. Importar contexto é opcional.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(FrondaTheme.border, lineWidth: 1))
    }
}
