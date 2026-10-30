import AppKit
import HarnessDomain
import HarnessInfrastructure
import SwiftUI

struct SettingsView: View {
    @Bindable var store: AppStore
    @Bindable var island: SessionIslandController
    let companion: MascotCompanionController
    @State private var diagnostics = ""
    @State private var integration = false
    @State private var updateResult = ""
    @State private var savingGeneralPreferences = false
    private let sections = [
        ("Geral", "slider.horizontal.3"), ("Extensões", "puzzlepiece.extension"), ("Providers", "terminal"),
        ("Integrações", "point.3.connected.trianglepath.dotted"), ("Privacidade", "hand.raised"),
        ("Armazenamento", "internaldrive"), ("Diagnóstico", "stethoscope"),
    ]
    var body: some View {
        NavigationSplitView {
            List(selection: $store.settingsSection) {
                ForEach(sections, id: \.0) { name, symbol in Label(name, systemImage: symbol).tag(name) }
            }.listStyle(.sidebar).navigationSplitViewColumnWidth(min: 180, ideal: 196, max: 230)
                .disabled(savingGeneralPreferences)
        } detail: {
            Group {
                if store.settingsSection == "Geral" {
                    GeneralSettingsView(
                        store: store, island: island, companion: companion, savingPreferences: $savingGeneralPreferences
                    )
                } else {
                    Form {
                        switch store.settingsSection {
                        case "Extensões": ExtensionsView(store: store)
                        case "Providers": ProviderConnectionsView(store: store)
                        case "Integrações": integrations
                        case "Privacidade": privacy
                        case "Armazenamento": storage
                        case "Diagnóstico": diagnosis
                        default: EmptyView()
                        }
                    }.formStyle(.grouped).scrollContentBackground(.hidden)
                        .contentMargins(.top, 8, for: .scrollContent)
                }
            }.navigationTitle(store.settingsSection).background(FrondaTheme.canvas)
        }.frame(minWidth: 900, idealWidth: 1000, minHeight: 660, idealHeight: 760).tint(FrondaTheme.accent)
            .preferredColorScheme(store.colorScheme)
            .sheet(isPresented: $integration) { IntegrationSettingsView(store: store) }
    }
    private var integrations: some View {
        Group {
            Section("Conexões explícitas") {
                ForEach(store.snapshot.preferences.integrationAccounts) { account in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(account.name).font(.headline)
                            Text(account.endpoint).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(text: account.connected ? "AVAILABLE" : "AUTH_REQUIRED")
                    }
                }
                Button("Adicionar conexão…") { integration = true }
            }
            Section {
                Text(
                    "GitHub.com / Enterprise e Jira Cloud. Autorizações ficam no Keychain; somente identificadores entram no armazenamento local. Escritas exigem proposta e confirmação."
                ).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private var privacy: some View {
        Group {
            Section("Local-first") {
                Label("Nenhuma telemetria de produto", systemImage: "checkmark.shield")
                Label("Eventos e artefatos neste Mac", systemImage: "internaldrive")
                Label("Credenciais no Keychain", systemImage: "key")
                Label("Contexto redigido antes do envio", systemImage: "eye.slash")
            }
            Section("Controles efetivos") {
                Text(
                    "Arquivos privados, sessões, bancos de apps, logs brutos, chaves e .env ficam fora do índice. Escritas são mediadas pelo Fronda; caminhos são canonizados, e shells implícitos são negados."
                )
                Text(
                    "Confinamento forte de processos externos precisa ser demonstrado. Ative a exigência por projeto para bloquear providers sem essa garantia."
                )
            }.font(.callout)
        }
    }
    private var storage: some View {
        Section("Armazenamento") {
            LabeledContent(
                "Banco local",
                value: ByteCountFormatter.string(fromByteCount: store.snapshot.storageBytes, countStyle: .file))
            LabeledContent("Histórico", value: "Preservado até ação explícita")
            Button("Mostrar armazenamento no Finder") {
                if let paths = try? StoragePaths() { store.reveal(paths.root.path) }
            }
            Button("Verificar pacote de atualização…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                guard panel.runModal() == .OK, let url = panel.url, url.pathExtension == "app" else { return }
                Task {
                    do {
                        updateResult = try await UpdateVerifier.verify(candidate: url, installed: Bundle.main.bundleURL)
                        store.reveal(url.path)
                    } catch { updateResult = error.localizedDescription }
                }
            }
            if !updateResult.isEmpty { Text(updateResult).font(.caption).textSelection(.enabled) }
            Text(
                "Exportações não incluem credenciais ou sessões dos providers. Worktrees com alterações são preservadas."
            ).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var diagnosis: some View {
        Section("Diagnóstico local") {
            Button("Atualizar diagnóstico") {
                Task {
                    do { diagnostics = try await store.send(RPCRequest("diagnostics")).text } catch {
                        store.error = error.localizedDescription
                    }
                }
            }
            Text(diagnostics.isEmpty ? "Consulte a versão do core e as capacidades dos providers." : diagnostics).font(
                .system(size: 11, design: .monospaced)
            ).textSelection(.enabled)
        }
    }
}
