import HarnessDomain
import SwiftUI

struct RunbooksView: View {
    var store: AppStore
    @State private var editing: Runbook?
    @SceneStorage("fronda.runbooks.search") private var search = ""
    @SceneStorage("fronda.runbooks.filter") private var filter = RunbookLibraryFilter.all
    @SceneStorage("fronda.runbooks.selection") private var selectedBookID: String?
    @SceneStorage("fronda.runbooks.step") private var selectedStepID: String?

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var filtered: [Runbook] {
        store.snapshot.runbooks.filter { book in
            filter.includes(book)
                && (query.isEmpty
                    || ([book.name, book.subtitle, book.provider.rawValue] + book.steps.map(\.title))
                        .contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }
    private var selectedBook: Runbook? {
        filtered.first { $0.id == selectedBookID } ?? filtered.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header.fixedSize(horizontal: false, vertical: true)
            Divider()
            if filtered.isEmpty {
                emptyState.frame(maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    if geometry.size.width >= 980 {
                        HStack(spacing: 0) {
                            library.frame(width: 230)
                            Divider()
                            detail
                        }
                    } else {
                        VStack(spacing: 0) {
                            compactLibrary
                            Divider()
                            detail
                        }
                    }
                }
            }
        }
        .sheet(item: $editing) { book in
            RunbookEditorView(store: store, book: book) { id in
                search = ""
                filter = .all
                selectedBookID = id
            }
        }
        .onChange(of: selectedBook?.id) { _, _ in selectedStepID = nil }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Fluxos").font(.system(size: 20, weight: .semibold)).tracking(-0.4)
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar fluxo ou etapa", text: $search).textFieldStyle(.plain)
                    .accessibilityLabel("Buscar fluxos").accessibilityIdentifier("runbooks.search")
                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain).accessibilityLabel("Limpar busca de fluxos")
                }
            }
            .font(.caption).padding(.horizontal, 9).padding(.vertical, 7)
            .frame(minWidth: 150, idealWidth: 235, maxWidth: 285)
            .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(FrondaTheme.border, lineWidth: 1))
            Picker("Tipo de fluxo", selection: $filter) {
                ForEach(RunbookLibraryFilter.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu).labelsHidden().fixedSize()
            .accessibilityIdentifier("runbooks.filter")
            Button("Criar fluxo", systemImage: "plus", action: create)
                .accessibilityIdentifier("runbooks.create")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("\(filtered.count) \(filtered.count == 1 ? "fluxo disponível" : "fluxos disponíveis")")
                .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                .padding(.horizontal, 17).padding(.top, 16)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filtered) { book in
                            libraryRow(book).id(book.id)
                        }
                    }.padding(.horizontal, 8).padding(.bottom, 12)
                }
                .onAppear { if let id = selectedBook?.id { proxy.scrollTo(id) } }
                .onChange(of: selectedBook?.id) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }.background(FrondaTheme.surface.opacity(0.55))
    }

    private var compactLibrary: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(filtered) { book in
                        libraryRow(book).frame(width: 206).id(book.id)
                    }
                }.padding(.horizontal, 12).padding(.vertical, 7)
            }
            .frame(height: 68)
            .onAppear { if let id = selectedBook?.id { proxy.scrollTo(id) } }
            .onChange(of: selectedBook?.id) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }.background(FrondaTheme.surface.opacity(0.55))
    }

    private func libraryRow(_ book: Runbook) -> some View {
        RunbookLibraryRow(book: book, selected: book.id == selectedBook?.id) {
            selectedBookID = book.id
        }
    }

    @ViewBuilder private var detail: some View {
        if let book = selectedBook {
            RunbookDetailView(
                book: book, selectedStepID: $selectedStepID, onUse: { use(book) }, onEdit: { editing = book }
            ).id(book.id)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            EmptyPanel(
                symbol: store.snapshot.runbooks.isEmpty ? "point.3.connected.trianglepath.dotted" : "magnifyingglass",
                title: store.snapshot.runbooks.isEmpty ? "Sua biblioteca começa aqui" : "Nenhum fluxo encontrado",
                detail: store.snapshot.runbooks.isEmpty
                    ? "Crie um fluxo com as etapas que fazem sentido para seu trabalho."
                    : "Tente outro nome, uma etapa ou mude o tipo de fluxo.")
            if !query.isEmpty || filter != .all {
                Button("Mostrar todos os fluxos") {
                    search = ""
                    filter = .all
                }
            } else {
                Button("Criar primeiro fluxo", action: create).buttonStyle(.borderedProminent)
            }
        }.padding(24)
    }

    private func create() {
        var book = Runbook()
        book.name = "Novo fluxo"
        book.steps = [RunbookStep(title: "Investigar", kind: "investigation")]
        editing = book
    }

    private func use(_ book: Runbook) {
        store.composerText = ""
        store.composerSource = nil
        store.composerProjectID = ""
        store.composerRunbookID = book.id
        store.showComposer = true
    }
}

private enum RunbookLibraryFilter: String, CaseIterable, Identifiable {
    case all = "Todos"
    case writes = "Com alterações"
    case readOnly = "Só leitura"

    var id: String { rawValue }
    func includes(_ book: Runbook) -> Bool {
        switch self {
        case .all: true
        case .writes: book.mode.writes
        case .readOnly: !book.mode.writes
        }
    }
}

private struct RunbookLibraryRow: View {
    let book: Runbook
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 9) {
                Image(systemName: book.symbol).font(.system(size: 15))
                    .foregroundStyle(FrondaTheme.accent).frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(book.name).font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .lineLimit(1).help(book.name)
                    Text("\(book.steps.count) etapas · \(book.mode.rawValue)")
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10).frame(height: 52)
            .background(selected ? FrondaTheme.accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(selected ? FrondaTheme.accent.opacity(0.25) : .clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(book.name), \(book.steps.count) etapas, \(book.mode.rawValue)")
        .accessibilityHint("Explorar este fluxo")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityRemoveTraits(selected ? [] : .isSelected)
        .accessibilityIdentifier("runbooks.select." + book.id)
    }
}
