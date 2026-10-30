import SwiftUI

struct CommandPaletteView: View {
    var store: AppStore
    let onSelect: (PaletteEntry.Action) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedID: String?
    @FocusState private var focused: Bool

    private var results: [PaletteEntry] { PaletteCatalog.entries(store: store, query: query) }
    private var selected: PaletteEntry? { results.first { $0.id == selectedID } ?? results.first }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Image(systemName: "magnifyingglass").font(.title3).foregroundStyle(FrondaTheme.accent)
                TextField("Buscar tarefa, projeto ou comando…", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 18)).focused($focused)
                    .accessibilityIdentifier("palette.search")
                    .onSubmit { if let selected { execute(selected) } }
                    .onKeyPress(.downArrow) {
                        moveSelection(by: 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveSelection(by: -1)
                        return .handled
                    }
                Button {
                    dismiss()
                } label: {
                    Text("esc").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        .padding(5).background(FrondaTheme.border.opacity(0.45), in: RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain).accessibilityLabel("Fechar busca").keyboardShortcut(.cancelAction)
            }.padding(24)
            Divider()
            if results.isEmpty {
                ContentUnavailableView.search(text: query).frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(PaletteCatalog.sections, id: \.self) { section in
                                let entries = results.filter { $0.section == section }
                                if !entries.isEmpty {
                                    Text(section.uppercased())
                                        .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                                        .foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 14).padding(
                                            .bottom, 5)
                                    ForEach(entries) { entry in
                                        PaletteResultRow(entry: entry, selected: selected?.id == entry.id) {
                                            execute(entry)
                                        }
                                        .id(entry.id)
                                    }
                                }
                            }
                        }.padding(.horizontal, 12).padding(.bottom, 14)
                    }
                    .onChange(of: selectedID) { _, id in
                        if let id { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
            Divider()
            HStack(spacing: 15) {
                Text("↑ ↓  navegar")
                Text("↩  abrir")
                Spacer()
                Text("\(results.count) resultados").monospacedDigit()
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 13)
        }
        .frame(width: 660, height: 520).background(FrondaTheme.canvas)
        .onAppear {
            focused = true
            selectedID = results.first?.id
        }
        .onChange(of: query) { _, _ in selectedID = results.first?.id }
        .onExitCommand { dismiss() }
    }

    private func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selectedID } ?? 0
        selectedID = results[max(0, min(results.count - 1, current + offset))].id
    }

    private func execute(_ entry: PaletteEntry) {
        onSelect(entry.action)
        dismiss()
    }
}
