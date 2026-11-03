import HarnessDomain
import SwiftUI

struct RunCheckupView: View {
    let store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection

    private var validators: [Validator] {
        guard let project = store.snapshot.projects.first(where: { $0.id == run.projectID }) else { return [] }
        return run.runbook.validators(for: project)
    }
    private var pendingFindings: [ReviewFinding] {
        run.findings.filter { ["OPEN", "ACCEPTED_RISK"].contains($0.state) }
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 1000 {
                HStack(alignment: .top, spacing: 0) {
                    checkupContent
                    Divider()
                    deliverySidebar.frame(width: 330)
                }
            } else {
                checkupContent
            }
        }
    }

    private var checkupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Conferência e entrega").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text("Confira as verificações, os achados e as evidências desta tarefa.")
                    .font(.callout).foregroundStyle(.secondary)
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Verificações", systemImage: "checkmark.shield").font(.headline)
                        Text("Comandos que conferem o resultado do trabalho.")
                            .font(.callout).foregroundStyle(.secondary)
                        if validators.isEmpty {
                            Text("Nenhuma verificação cadastrada.").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(validators) { validator in
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(validator.name).font(.callout.weight(.medium))
                                    Text(validator.displayCommand).font(.caption.monospaced()).foregroundStyle(
                                        .secondary)
                                }
                                Spacer()
                                if !validator.approved {
                                    FrondaBadge(
                                        "Precisa de aprovação", symbol: "hand.raised", color: FrondaTheme.warning)
                                } else if let result = run.validations.last(where: { $0.validator.id == validator.id })
                                {
                                    StatusBadge(
                                        text: result.validator == validator
                                            ? RunFollowupEvidence.status(of: result, in: run).rawValue : "STALE")
                                } else {
                                    StatusBadge(text: "NOT_RUN")
                                }
                            }
                        }
                        Button("Conferir verificações") { section = .validation }
                            .help("Abrir comandos, aprovações e resultados de validação")
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Revisão", systemImage: "text.magnifyingglass").font(.headline)
                        Text(
                            pendingFindings.isEmpty
                                ? "Nenhum achado pendente registrado."
                                : "\(pendingFindings.count) achado(s) aguardam resolução."
                        )
                        .font(.callout).foregroundStyle(.secondary)
                        Button("Conferir revisão") { section = .review }
                            .help("Abrir o parecer e resolver achados da revisão")
                        Button("Conferir cenários") { section = .scenarios }
                            .help("Abrir observações e evidências dos cenários")
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Evidências", systemImage: "doc.richtext").font(.headline)
                        Text("\((run.evidenceArtifacts ?? []).count) artefato(s) registrado(s).")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Conferir evidências e entrega") { section = .evidence }
                            .help("Abrir critérios, evidências e opções de entrega")
                    }
                }
            }.padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
    }

    private var deliverySidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("O que falta para entregar", systemImage: "shippingbox")
                    .font(.title3.weight(.semibold)).foregroundStyle(FrondaTheme.accent)
                    .accessibilityAddTraits(.isHeader)
                Text("Confira as pendências e abra cada área para tomar as decisões necessárias.")
                    .font(.callout).foregroundStyle(.secondary)
                if !run.contextApproved {
                    deliveryLink(
                        "Revisar contexto", detail: "Confira os arquivos e o destino antes da autorização.",
                        symbol: "person.crop.circle", destination: .context)
                }
                if validators.contains(where: { $0.required && !$0.approved }) {
                    deliveryLink(
                        "Revisar verificações", detail: "Confira os comandos que aguardam aprovação.",
                        symbol: "checkmark.shield", destination: .validation)
                }
                if !pendingFindings.isEmpty {
                    deliveryLink(
                        "Conferir achados", detail: "Examine os pontos registrados pela revisão.",
                        symbol: "text.magnifyingglass", destination: .review)
                }
                deliveryLink(
                    "Conferir entrega", detail: "Revise critérios e evidências da versão atual.",
                    symbol: "shippingbox", destination: .evidence)
                Divider()
                Text("Pendências registradas").font(.headline)
                ForEach(
                    Array(RunFollowupModel(run: run, isConnected: store.connected).remaining.enumerated()), id: \.offset
                ) {
                    _, item in
                    Label(item, systemImage: "circle").font(.callout).foregroundStyle(.secondary)
                }
                if let squirrel = FrondaAssets.gardenSquirrel {
                    Image(nsImage: squirrel).resizable().interpolation(.high).scaledToFit()
                        .frame(maxWidth: 200).opacity(0.75)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityHidden(true)
                }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
        }.background(FrondaTheme.surface)
    }

    private func deliveryLink(
        _ title: String, detail: String, symbol: String, destination: RunWorkspaceSection
    ) -> some View {
        Button {
            section = destination
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).foregroundStyle(FrondaTheme.accent).frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(FrondaTheme.canvas.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .help(detail)
    }
}
