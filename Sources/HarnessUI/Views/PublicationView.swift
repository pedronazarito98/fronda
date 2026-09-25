import HarnessDomain
import HarnessInfrastructure
import SwiftUI

struct PublicationView: View {
    var store: AppStore
    let run: Run
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "git.commit"
    @State private var destination = ""
    @State private var payload = ""
    @State private var title = ""
    @State private var base = ""
    @State private var repository = ""
    @State private var error: String?
    @State private var working = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preparar operação").font(.title2.weight(.semibold))
            Text(
                "A operação ficará em Decisões, com payload, destino e hash deste snapshot. A preparação não executa a escrita."
            ).font(.callout).foregroundStyle(.secondary)
            Picker("Ação", selection: $kind) {
                Text("Commit local").tag("git.commit")
                Text("Push da branch").tag("git.push")
                Text("Criar PR GitHub").tag("github.pr")
                Text("Comentário GitHub").tag("github.comment")
                Text("Comentário Jira").tag("jira.comment")
                Text("Transição Jira").tag("jira.transition")
            }
            if !kind.hasPrefix("git.") && kind != "github.pr" {
                TextField("Path REST na conexão (ex.: repos/owner/repo/pulls)", text: $destination).textFieldStyle(
                    .roundedBorder)
            }
            if kind == "github.pr" {
                TextField("Repositório (organização/nome)", text: $repository).textFieldStyle(.roundedBorder)
                TextField("Título", text: $title).textFieldStyle(.roundedBorder)
                TextField("Branch de destino", text: $base).textFieldStyle(.roundedBorder)
                LabeledContent("Branch da tarefa", value: run.branch)
                Label("O PR será criado como rascunho", systemImage: "doc.badge.ellipsis").font(.caption)
            }
            Text(
                kind == "github.pr"
                    ? "Descrição da alteração e validação"
                    : kind.hasPrefix("git.") ? "Mensagem / descrição da operação" : "Corpo JSON exato"
            ).font(.headline)
            TextEditor(text: $payload).font(.system(size: 12, design: .monospaced)).frame(height: 220).border(
                .quaternary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Text("Snapshot \(run.revision.prefix(16))").font(.caption.monospaced()).foregroundStyle(.secondary)
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Preparar proposta") { prepare() }.disabled(payload.isEmpty || working).buttonStyle(
                    .borderedProminent)
            }
        }.padding(28).frame(width: 720).onAppear {
            title = run.title
            payload = run.title
            if let project = store.snapshot.projects.first(where: { $0.id == run.projectID }) {
                base = project.branch
                let remote = project.remote.replacingOccurrences(of: ".git", with: "")
                if let url = URL(string: remote), url.scheme == "https" {
                    repository = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                } else if let colon = remote.firstIndex(of: ":") {
                    repository = String(remote[remote.index(after: colon)...])
                }
            }
        }
        .onChange(of: kind) { _, next in
            payload = next == "github.pr" ? run.report : next.hasPrefix("git.") ? run.title : "{\n  \"body\": \"\"\n}"
        }
    }
    private func prepare() {
        working = true
        Task {
            do {
                var approval = Approval()
                approval.kind = kind
                approval.title = kind == "github.pr" ? "Criar PR em rascunho" : kind
                approval.payload = payload
                approval.destination = destination
                if kind == "github.pr" {
                    guard repository.split(separator: "/").count == 2, !base.isEmpty, !title.isEmpty else {
                        throw HarnessError("Informe repositório, título e branch de destino.")
                    }
                    approval.destination = "repos/" + repository + "/pulls"
                    approval.payload = try Coding.string(
                        JSONValue.object([
                            "title": .string(title), "head": .string(run.branch), "base": .string(base),
                            "body": .string(payload), "draft": .bool(true),
                        ]))
                }
                var request = RPCRequest("approval.prepare")
                request.id = run.id
                request.approval = approval
                request.expectedSequence = run.sequence
                _ = try await store.send(request)
                await store.refresh()
                dismiss()
            } catch { self.error = error.localizedDescription }
            working = false
        }
    }
}
