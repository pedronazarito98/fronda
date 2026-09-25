import AppKit
import HarnessDomain
import HarnessInfrastructure
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var store: AppStore
    @Bindable var island: SessionIslandController
    @State private var selection = "Geral"
    @State private var diagnostics = ""
    @State private var integration = false
    @State private var updateResult = ""
    private let sections = [
        ("Geral", "slider.horizontal.3"), ("Extensões", "puzzlepiece.extension"), ("Providers", "terminal"),
        ("Integrações", "point.3.connected.trianglepath.dotted"), ("Privacidade", "hand.raised"),
        ("Armazenamento", "internaldrive"), ("Diagnóstico", "stethoscope"),
    ]
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(sections, id: \.0) { name, symbol in Label(name, systemImage: symbol).tag(name) }
            }.listStyle(.sidebar).navigationSplitViewColumnWidth(170)
        } detail: {
            Form {
                switch selection {
                case "Extensões": ExtensionsView(store: store)
                case "Providers": providers
                case "Integrações": integrations
                case "Privacidade": privacy
                case "Armazenamento": storage
                case "Diagnóstico": diagnosis
                default: general
                }
            }.formStyle(.grouped).navigationTitle(selection)
        }.frame(width: 850, height: 640).tint(HarnessTheme.accent)
            .sheet(isPresented: $integration) { IntegrationSettingsView(store: store) }
    }
    private var general: some View {
        Group {
            Section("Aparência") {
                Picker("Tema", selection: preference(\.appearance)) {
                    ForEach(["Sistema", "Claro", "Escuro"], id: \.self) { Text($0) }
                }.accessibilityIdentifier("settings.appearance")
            }
            Section("Central de sessões") {
                Toggle("Mostrar ilha no topo da tela", isOn: $island.enabled)
                    .accessibilityIdentifier("settings.island-enabled")
                Toggle("Mostrar prévia ao passar o mouse", isOn: $island.expandOnHover)
                    .disabled(!island.enabled)
                Button("Abrir central (⌥⌘I)") {
                    island.enabled = true
                    island.expand(focus: true)
                }
                Text("Usa o notch do MacBook ou uma ilha abaixo da barra de menus em monitores sem notch.")
                    .font(.caption).foregroundStyle(.secondary)
                ExternalSessionSetupView()
            }
            Section("Execução") {
                Toggle(
                    "Abrir Harness ao iniciar sessão",
                    isOn: Binding(
                        get: { SMAppService.mainApp.status == .enabled },
                        set: { enabled in
                            Task {
                                do {
                                    if enabled {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try await SMAppService.mainApp.unregister()
                                    }
                                } catch { store.error = error.localizedDescription }
                            }
                        }))
                Stepper(
                    "Runs simultâneas: \(store.snapshot.preferences.concurrency)", value: preference(\.concurrency),
                    in: 1...8)
                Stepper(
                    "Por projeto: \(store.snapshot.preferences.perProjectConcurrency)",
                    value: preference(\.perProjectConcurrency), in: 1...8)
                Stepper(
                    "Por provider: \(store.snapshot.preferences.perProviderConcurrency)",
                    value: preference(\.perProviderConcurrency), in: 1...8)
                Stepper(
                    "Orçamento padrão: \(store.snapshot.preferences.tokenBudget.formatted()) tokens",
                    value: preference(\.tokenBudget), in: 1000...500000, step: 1000)
                Stepper(
                    "Contexto: \(store.snapshot.preferences.contextBudget.formatted()) tokens estimados",
                    value: preference(\.contextBudget), in: 1000...100000, step: 1000)
            }
            Section("Notificações") {
                Toggle("Decisões e resultados", isOn: preference(\.notifications))
                Button("Autorizar notificações no macOS…") { store.requestNotifications() }
            }
            Section("Atalhos") {
                LabeledContent("Nova run", value: "⌘N")
                LabeledContent("Busca e comandos", value: "⌘K")
                LabeledContent("Command Center / Runs / Projetos / Decisões", value: "⌘1–4")
                LabeledContent("Ajustes", value: "⌘,")
            }
        }
    }
    private var providers: some View {
        Group {
            Section("Instalações locais") {
                ForEach(store.snapshot.providers) { provider in
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Text(provider.kind.rawValue).font(.headline)
                            Spacer()
                            StatusBadge(text: provider.state)
                        }
                        Text(provider.version).font(.caption.monospaced())
                        Text(provider.detail).font(.callout).foregroundStyle(.secondary)
                        TextField(
                            "Caminho do executável",
                            text: Binding(
                                get: { store.snapshot.preferences.providers[provider.kind.rawValue] ?? provider.path },
                                set: { path in
                                    var prefs = store.snapshot.preferences
                                    prefs.providers[provider.kind.rawValue] = path
                                    store.snapshot.preferences = prefs
                                }))
                    }.padding(.vertical, 10)
                }
                Button("Salvar caminhos e verificar capacidades") {
                    store.savePreferences(store.snapshot.preferences)
                    store.perform("providers.probe")
                }
            }
            Section {
                Text(
                    "A autenticação acontece nos CLIs oficiais. O Harness não lê arquivos de sessão, histórico privado ou tokens dos providers."
                ).font(.caption).foregroundStyle(.secondary)
            }
        }
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
                    "Arquivos privados, sessões, bancos de apps, logs brutos, chaves e .env ficam fora do índice. Escritas são mediadas pelo Harness; caminhos são canonizados, e shells implícitos são negados."
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
    private func preference<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { store.snapshot.preferences[keyPath: keyPath] },
            set: { newValue in
                var prefs = store.snapshot.preferences
                prefs[keyPath: keyPath] = newValue
                store.snapshot.preferences = prefs
                store.savePreferences(prefs)
            })
    }
}
