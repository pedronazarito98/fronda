import HarnessDomain
import ServiceManagement
import SwiftUI
import UserNotifications

struct GeneralSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var store: AppStore
    let island: SessionIslandController
    let companion: MascotCompanionController
    @Binding var savingPreferences: Bool
    @State private var pendingPreferences: AppPreferences?
    @State private var saveNotice = ""
    @State private var localError: String?
    @State private var advanced = false
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginRequiresApproval = SMAppService.mainApp.status == .requiresApproval
    @State private var changingLogin = false
    @State private var requestingNotifications = false

    private var preferences: AppPreferences { pendingPreferences ?? store.snapshot.preferences }
    private var saving: Bool { pendingPreferences != nil }
    private var preferencesDisabled: Bool { saving || !store.connected || requestingNotifications }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Do seu jeito.").font(.system(size: 26, weight: .semibold)).tracking(-0.5)
                        Text("Ajuste a aparência e como a Fronda acompanha seu trabalho.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if saving {
                        ProgressView().controlSize(.small).accessibilityLabel("Salvando preferência")
                    } else if !saveNotice.isEmpty {
                        Label(saveNotice, systemImage: "checkmark.circle")
                            .font(.caption2).foregroundStyle(FrondaTheme.success)
                    }
                }.padding(.vertical, 5)
            }.listRowBackground(Color.clear)
            if !store.connected {
                Section {
                    Label(
                        "Reconecte ao coordenador para salvar preferências de execução e aparência.",
                        systemImage: "wifi.exclamationmark"
                    )
                    .font(.callout).foregroundStyle(FrondaTheme.warning)
                    Button("Tentar novamente") { Task { await store.refresh() } }
                }
            }
            Section {
                SettingsAppearancePicker(selection: preference(\.appearance))
                    .disabled(preferencesDisabled)
            }
            Section {
                SettingsSessionIsland(island: island)
            }
            Section { SettingsMascotCompanion(companion: companion) }
            Section("No dia a dia") {
                Toggle(isOn: Binding(get: { loginEnabled }, set: changeLogin)) {
                    settingsLabel(
                        "Abrir com o Mac", detail: "Tenha a Fronda pronta quando iniciar a sessão.", symbol: "power")
                }
                .toggleStyle(.switch).disabled(changingLogin)
                .accessibilityLabel("Abrir com o Mac")
                .accessibilityHint("Inicia a Fronda ao entrar na sua sessão do macOS.")
                if loginRequiresApproval {
                    Label(
                        "Autorize a Fronda em Ajustes do Sistema → Geral → Itens de Início e Extensões.",
                        systemImage: "exclamationmark.circle"
                    ).font(.caption).foregroundStyle(FrondaTheme.warning)
                }
                Toggle(isOn: preference(\.notifications)) {
                    settingsLabel(
                        "Avisar quando precisar de mim", detail: "Decisões pendentes e resultados de tarefas.",
                        symbol: "bell.badge")
                }.toggleStyle(.switch).disabled(preferencesDisabled)
                    .accessibilityLabel("Avisar quando precisar de mim")
                    .accessibilityHint("Decisões pendentes e resultados de tarefas.")
                HStack {
                    Text("As notificações também precisam de autorização do macOS.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if requestingNotifications { ProgressView().controlSize(.small) }
                    Button("Autorizar…", action: requestNotifications).disabled(preferencesDisabled)
                }
            }
            Section {
                DisclosureGroup(isExpanded: $advanced) {
                    SettingsExecutionControls(
                        concurrency: preference(\.concurrency), perProject: preference(\.perProjectConcurrency),
                        perProvider: preference(\.perProviderConcurrency), tokenBudget: preference(\.tokenBudget),
                        contextBudget: preference(\.contextBudget)
                    ).padding(.top, 16).disabled(preferencesDisabled)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(FrondaTheme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Execução e limites").font(.callout.weight(.medium))
                            Text(
                                "Até \(preferences.concurrency) tarefas em paralelo · padrão geral de \(preferences.tokenBudget.formatted()) tokens"
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 5)
                }.accessibilityIdentifier("settings.execution-limits")
            }
        }
        .formStyle(.grouped).scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
        .background(FrondaTheme.canvas)
        .onAppear(perform: refreshLoginStatus)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !changingLogin { refreshLoginStatus() }
        }
        .alert(
            "Não foi possível salvar",
            isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })
        ) {
            Button("OK") { localError = nil }
        } message: {
            Text(localError ?? "")
        }
    }

    private func settingsLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(FrondaTheme.accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
    }

    private func preference<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { value in
                guard !saving else { return }
                var updated = store.snapshot.preferences
                updated[keyPath: keyPath] = value
                save(updated)
            })
    }

    private func save(_ preferences: AppPreferences) {
        guard !saving else { return }
        pendingPreferences = preferences
        savingPreferences = true
        saveNotice = ""
        Task {
            defer {
                pendingPreferences = nil
                savingPreferences = false
            }
            do {
                var request = RPCRequest("preferences.save")
                request.preferences = preferences
                _ = try await store.send(request)
                store.snapshot.preferences = preferences
                saveNotice = "Salvo"
            } catch { localError = error.localizedDescription }
        }
    }

    private func changeLogin(_ enabled: Bool) {
        guard !changingLogin else { return }
        loginEnabled = enabled
        changingLogin = true
        Task {
            do {
                if enabled { try SMAppService.mainApp.register() } else { try await SMAppService.mainApp.unregister() }
            } catch {
                localError = error.localizedDescription
            }
            refreshLoginStatus()
            changingLogin = false
        }
    }

    private func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        loginEnabled = status == .enabled
        loginRequiresApproval = status == .requiresApproval
    }

    private func requestNotifications() {
        requestingNotifications = true
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [
                    .alert, .sound, .badge,
                ])
                var updated = store.snapshot.preferences
                updated.notifications = allowed
                save(updated)
                if !allowed {
                    localError =
                        "As notificações estão desativadas no macOS. Você pode autorizá-las em Ajustes do Sistema → Notificações → Fronda."
                }
            } catch { localError = error.localizedDescription }
            requestingNotifications = false
        }
    }
}
