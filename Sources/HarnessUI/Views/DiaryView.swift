import HarnessDomain
import SwiftUI

struct DiaryView: View {
    var store: AppStore
    @State private var query = ""
    @State private var projectID = ""
    @State private var consolidated = false
    private var entries: [Run] {
        store.snapshot.runs.filter {
            (projectID.isEmpty || $0.projectID == projectID)
                && (!consolidated || $0.workflow?.delivery.closedAt != nil)
                && (query.isEmpty
                    || ($0.title + " " + ($0.workflow?.reference ?? "") + " " + $0.report)
                        .localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(
                    eyebrow: "Memória do trabalho", title: "Diário",
                    subtitle: "Decisões, cenários, alterações e entregas. O registro começa junto com a tarefa.")
                HStack {
                    TextField("Buscar tarefa, card ou resultado", text: $query).textFieldStyle(.roundedBorder)
                    Picker("Projeto", selection: $projectID) {
                        Text("Todos os projetos").tag("")
                        ForEach(store.snapshot.projects) { Text($0.name).tag($0.id) }
                    }.frame(maxWidth: 260)
                    Toggle("Consolidados", isOn: $consolidated).toggleStyle(.switch)
                }
                if entries.isEmpty {
                    EmptyPanel(
                        symbol: "book.closed", title: "Nenhum registro encontrado",
                        detail: "As tarefas aparecem aqui com suas evidências, inclusive antes da publicação.")
                }
                ForEach(entries) { run in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(run.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(run.workflow?.delivery.closedAt == nil ? "Rascunho" : "Consolidado").font(
                                .caption.weight(.medium))
                        }
                        RunRow(store: store, run: run)
                        HStack {
                            Text(
                                "\(run.workflow?.observations.count ?? 0) cenários · \(run.reportedTokens.formatted()) tokens reportados"
                            )
                            Spacer()
                            if let link = run.workflow?.delivery.pullRequestURL, let url = URL(string: link) {
                                Link("Abrir PR", destination: url)
                            }
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(32).frame(maxWidth: 1200)
        }
    }
}
