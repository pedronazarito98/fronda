import HarnessDomain
import SwiftUI

struct DiffView: View {
    var store: AppStore
    let run: Run
    @State private var selected = ""
    @State private var sideBySide = false
    @State private var selectedHunk = ""
    @State private var comment = ""
    private var sections: [DiffSection] { DiffSection.parse(run.diff) }
    private var current: DiffSection? { sections.first { $0.path == selected } ?? sections.first }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Arquivo", selection: $selected) {
                    Text("Todos / primeiro arquivo").tag("")
                    ForEach(run.changedFiles) { Text($0.path).tag($0.path) }
                }.frame(maxWidth: 400)
                Spacer()
                Toggle("Lado a lado", isOn: $sideBySide).toggleStyle(.switch).controlSize(.small)
                if let current {
                    Button {
                        store.openFile(run.workspace + "/" + current.path)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    Button {
                        store.perform("context.update", id: run.id) {
                            $0.text = "lock"
                            $0.path = current.path
                        }
                    } label: {
                        Image(systemName: run.lockedPaths.contains(current.path) ? "lock.fill" : "lock.open")
                    }.disabled(run.state.active)
                }
            }.padding(18)
            Divider()
            if let current {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(current.lines.enumerated()), id: \.offset) { index, row in
                            let line = row.text
                            HStack(alignment: .top, spacing: 0) {
                                Text(sideBySide ? (row.oldNumber.map(String.init) ?? "·") : row.number).foregroundStyle(
                                    .tertiary
                                ).frame(width: 38, alignment: .trailing).padding(.trailing, 12)
                                if sideBySide {
                                    Text(line.hasPrefix("+") ? "" : line).frame(
                                        minWidth: 420, maxWidth: .infinity, alignment: .leading)
                                    Divider()
                                    Text(row.newNumber.map(String.init) ?? "·").foregroundStyle(.tertiary).frame(
                                        width: 38)
                                    Text(line.hasPrefix("-") ? "" : line).frame(
                                        minWidth: 420, maxWidth: .infinity, alignment: .leading
                                    ).padding(.leading, 10)
                                } else {
                                    Text(line).frame(minWidth: 650, maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .font(.system(size: 11, design: .monospaced)).padding(.vertical, 3).padding(.horizontal, 5)
                            .foregroundStyle(
                                line.hasPrefix("+") ? Color.green : line.hasPrefix("-") ? Color.red : .primary
                            )
                            .background(
                                line.hasPrefix("+")
                                    ? Color.green.opacity(0.06)
                                    : line.hasPrefix("-")
                                        ? Color.red.opacity(0.06)
                                        : line.hasPrefix("@@") ? Color.blue.opacity(0.08) : Color.clear
                            )
                            .textSelection(.enabled)
                            .onTapGesture { selectedHunk = "\(current.path):\(row.number)\n\(current.hunk(at: index))" }
                            .contextMenu {
                                Button("Comentar este trecho") {
                                    selectedHunk = "\(current.path):\(row.number)\n\(current.hunk(at: index))"
                                }
                                Button("Explicar este trecho") {
                                    store.perform("run.steer", id: run.id) {
                                        $0.path = current.path
                                        $0.text =
                                            "Explique com evidências este trecho: \(current.path)\n\(current.hunk(at: index))"
                                    }
                                }
                            }
                        }
                    }
                }
                if !selectedHunk.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedHunk).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2)
                        HStack {
                            TextField("Comentário ou orientação neste trecho", text: $comment)
                            Button("Registrar e orientar") {
                                store.perform("run.steer", id: run.id) {
                                    $0.path = current.path
                                    $0.text = "Trecho: \(selectedHunk)\n\(comment)"
                                }
                                comment = ""
                                selectedHunk = ""
                            }.disabled(comment.isEmpty)
                        }
                    }.padding(16)
                }
            } else {
                Spacer()
                EmptyPanel(
                    symbol: "arrow.left.arrow.right",
                    title: run.changedFiles.isEmpty ? "Nenhuma alteração neste snapshot" : "Alteração sem diff textual",
                    detail: "Arquivos binários ou excluídos pelo firewall são apresentados apenas por metadados.")
                Spacer()
            }
        }
    }
}
