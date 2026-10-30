import HarnessDomain
import SwiftUI

struct GuideView: View {
    @Bindable var store: AppStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SceneStorage("fronda.guide.query") private var query = ""
    @State private var importing: ProviderKind?
    private var topic: GuideTopic? { GuideTopic.topics.first { $0.id == store.guideTopic } }
    private var topics: [GuideTopic] {
        GuideTopic.topics.filter {
            query.isEmpty
                || "\($0.title) \($0.subtitle) \($0.steps.map(\.text).joined())".localizedStandardContains(query)
        }
    }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    FirstTaskJourneyEntry(store: store)
                    GuideJourney(store: store) { id in
                        store.guideTopic = id
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            reader.scrollTo("guide-detail", anchor: .top)
                        }
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Como fazer").font(.title2.weight(.semibold))
                            Text("Um atalho para quando você precisar.").font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField("O que você quer aprender?", text: $query)
                            .textFieldStyle(.roundedBorder).frame(width: 300)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                        ForEach(topics) { topic in
                            Button {
                                store.guideTopic = topic.id
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                                    reader.scrollTo("guide-detail", anchor: .top)
                                }
                            } label: {
                                topicCard(topic)
                            }.buttonStyle(.plain).accessibilityIdentifier("guide.topic." + topic.id)
                        }
                    }
                    if topics.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                    if let topic {
                        topicDetail(topic).id("guide-detail")
                    }
                    HStack {
                        Label("Disponível no menu Ajuda e na busca ⌘K", systemImage: "questionmark.circle")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Ir para a visão geral") { finish() }.buttonStyle(.link)
                    }
                }.padding(30).frame(maxWidth: 1140).frame(maxWidth: .infinity)
            }.onChange(of: store.guideTopic, initial: true) {
                if topic != nil {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        reader.scrollTo("guide-detail", anchor: .top)
                    }
                }
            }
        }.sheet(item: $importing) { ProviderImportView(store: store, provider: $0) }
            .accessibilityIdentifier("guide.home")
    }

    private var hero: some View {
        HStack(spacing: 25) {
            VStack(alignment: .leading, spacing: 15) {
                Label("GUIA FRONDA", systemImage: "leaf.fill").font(.system(size: 10, weight: .bold)).tracking(2)
                    .foregroundStyle(FrondaTheme.accent)
                Text(store.snapshot.runs.isEmpty ? "Seu trabalho.\nUm novo começo." : "Sempre há um\npróximo passo.")
                    .font(.system(size: 35, weight: .semibold, design: .rounded)).tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Traga o que você já sabe, escolha quem vai ajudar e acompanhe sua ideia até a entrega.")
                    .font(.callout).foregroundStyle(.secondary).frame(maxWidth: 480, alignment: .leading)
                HStack(spacing: 12) {
                    Button(nextActionTitle) { nextAction() }.buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(!store.connected)
                    if store.snapshot.preferences.onboardingCompleted != true {
                        Button("Explorar por conta própria") { finish() }.buttonStyle(.link)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                Circle().fill(FrondaTheme.sage.opacity(0.14)).frame(width: 210, height: 210)
                Circle().strokeBorder(FrondaTheme.accent.opacity(0.13), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                    .frame(width: 240, height: 240)
                FrondaMascot(size: 176)
                Label("Crie raízes aqui", systemImage: "sparkle").font(.caption.weight(.medium))
                    .padding(.horizontal, 13).padding(.vertical, 8).background(.regularMaterial, in: Capsule())
                    .offset(y: 100)
            }.frame(width: 250, height: 255).accessibilityHidden(true)
        }.padding(28)
            .background(
                LinearGradient(
                    colors: [FrondaTheme.accent.opacity(0.09), FrondaTheme.surface], startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 26))
    }

    private func topicCard(_ topic: GuideTopic) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: topic.symbol).font(.system(size: 20, weight: .light))
                .foregroundStyle(FrondaTheme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 7) {
                Text(topic.title).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                Text(topic.subtitle).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
        }.padding(19).frame(maxWidth: .infinity, minHeight: 91, alignment: .topLeading)
            .background(
                store.guideTopic == topic.id ? FrondaTheme.accent.opacity(0.10) : FrondaTheme.surface,
                in: RoundedRectangle(cornerRadius: 15)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15).strokeBorder(
                    store.guideTopic == topic.id ? FrondaTheme.accent.opacity(0.5) : FrondaTheme.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 15))
    }

    private func topicDetail(_ topic: GuideTopic) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label(topic.title, systemImage: topic.symbol).font(.title2.weight(.semibold))
                Spacer()
                if topic.id == "context" {
                    Menu(topic.action) {
                        ForEach(ProviderKind.allCases) { kind in Button(kind.rawValue) { importing = kind } }
                    }.menuStyle(.borderlessButton).fixedSize()
                } else {
                    Button(topic.action) { act(on: topic.id) }.buttonStyle(.borderedProminent)
                }
            }
            ForEach(Array(topic.steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 16) {
                    Text("\(index + 1)").font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(FrondaTheme.accent).frame(width: 30, height: 30)
                        .background(FrondaTheme.accent.opacity(0.09), in: Circle())
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title).font(.headline)
                        Text(step.text).font(.callout).foregroundStyle(.secondary).fixedSize(
                            horizontal: false, vertical: true)
                    }
                }
            }
        }.padding(26).background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private var nextActionTitle: String {
        if !store.snapshot.providers.contains(where: { $0.state == "AVAILABLE" }) { return "Conectar meu executor" }
        if store.snapshot.projects.isEmpty { return "Adicionar meu projeto" }
        return store.firstTaskJourney.entryTitle
    }
    private func nextAction() {
        if !store.snapshot.providers.contains(where: { $0.state == "AVAILABLE" }) {
            act(on: "providers")
        } else if store.snapshot.projects.isEmpty {
            store.addProject()
        } else {
            store.openFirstTaskJourney()
        }
    }
    private func act(on id: String) {
        switch id {
        case "providers":
            store.settingsSection = "Providers"
            openSettings()
        case "first-task":
            store.openFirstTaskJourney()
        case "models":
            if let run = store.snapshot.runs.first(where: { $0.state != .archived }) {
                store.route = "run:" + run.id
            } else {
                store.showComposer = true
            }
        case "review": store.route = "runs"
        case "shortcuts": store.showPalette = true
        default: break
        }
    }
    private func finish() {
        store.perform("onboarding.complete") { $0.flag = true }
        store.route = "center"
    }
}
