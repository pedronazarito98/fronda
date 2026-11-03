import HarnessDomain
import QuickLook
import SwiftUI

struct ArtifactReadButton: View {
    let store: AppStore
    let runID: String
    let artifact: EvidenceArtifact
    @State private var opening = false
    @State private var reader: RunFileSource?
    @State private var media: URL?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button(opening ? "Abrindo…" : "Visualizar") { opening = true }
                .disabled(!store.connected || opening)
                .accessibilityLabel("Visualizar " + artifact.title)
                .accessibilityIdentifier("artifact.open." + artifact.id)
            if let error { Text(error).font(.caption).foregroundStyle(FrondaTheme.danger) }
        }
        .task(id: opening) {
            guard opening else { return }
            defer { opening = false }
            error = nil
            do {
                let usesQuickLook = RunFileSource.prefersQuickLook(for: "evidence." + artifact.fileExtension)
                guard usesQuickLook || artifact.byteCount <= RunFileLoader.byteLimit else {
                    throw HarnessError(
                        "Esta evidência excede o limite de leitura de \(RunFileLoader.byteLimit / 1024) KiB.")
                }
                var request = RPCRequest("evidence.file")
                request.id = runID
                request.relatedID = artifact.id
                let path = try await store.send(request).path
                try Task.checkCancellation()
                guard path.hasPrefix("/") else { throw HarnessError("A cópia da evidência está indisponível.") }
                let url = URL(fileURLWithPath: path)
                if usesQuickLook {
                    media = url
                } else {
                    reader = .artifact(url: url, name: artifact.title)
                }
            } catch is CancellationError {
            } catch { self.error = error.localizedDescription }
        }
        .sheet(item: $reader) { RunFileReader(source: $0) }
        .quickLookPreview($media)
    }
}
