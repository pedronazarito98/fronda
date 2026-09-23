import Foundation
import HarnessDomain
import ImageIO
import PDFKit
import Vision

public enum AttachmentCompiler {
    /// Only explicitly selected attachments enter this path. Credentials, logs,
    /// databases and symlinks remain excluded before opening their contents.
    public static func compile(_ selections: [String]) throws -> [ContextItem] {
        var urls = [URL]()
        for selection in selections {
            let url = URL(fileURLWithPath: selection)
            guard ContextFirewall.exclusion(selection) == nil else {
                throw HarnessError("Anexo excluído pelo firewall: \(url.lastPathComponent)")
            }
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw HarnessError("Selecione o arquivo original, sem link simbólico.")
            }
            if values.isDirectory == true {
                let enumerator = FileManager.default.enumerator(
                    at: url, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles])
                while let child = enumerator?.nextObject() as? URL {
                    if ContextFirewall.exclusion(child.path) != nil {
                        enumerator?.skipDescendants()
                        continue
                    }
                    let attributes = try child.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if attributes.isRegularFile == true && attributes.isSymbolicLink != true { urls.append(child) }
                    guard urls.count <= 40 else {
                        throw HarnessError("Selecione até 40 arquivos por fonte. Restrinja a pasta selecionada.")
                    }
                }
            } else {
                urls.append(url)
            }
        }
        guard urls.count <= 40 else { throw HarnessError("Selecione até 40 anexos por fonte.") }
        return try urls.enumerated().map { index, url in
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 10_000_000 else { throw HarnessError("Anexo maior que 10 MB: \(url.lastPathComponent)") }
            let data = try Data(contentsOf: url)
            var item = try compile(data: data, filename: url.lastPathComponent)
            item.path = "attachments/\(index + 1)/\(url.lastPathComponent)"
            return item
        }
    }

    public static func validateFilename(_ filename: String) throws {
        guard !filename.isEmpty, filename != ".", filename != "..", filename.utf8.count <= 255,
            !filename.contains("/"), !filename.contains("\\"),
            filename.rangeOfCharacter(from: .controlCharacters) == nil,
            ContextFirewall.exclusion(filename) == nil
        else { throw HarnessError("Anexo privado ou nome de arquivo inválido.") }
    }

    /// Shared extraction for explicitly authorized local and Jira attachments.
    /// Remote bytes remain in memory; only the redacted source enters the store.
    public static func compile(data: Data, filename: String) throws -> ContextItem {
        try validateFilename(filename)
        guard data.count <= 10_000_000 else { throw HarnessError("Anexo maior que 10 MB: \(filename)") }
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        let text: String
        let classification: String
        if ["png", "jpg", "jpeg", "heic", "tiff"].contains(ext) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { throw HarnessError("Imagem inválida: \(filename)") }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: image).perform([request])
            text =
                "[Screenshot: texto reconhecido localmente. Os pixels não serão enviados.]\n"
                + (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            classification = "screenshot-ocr"
        } else if ext == "pdf" {
            guard let document = PDFDocument(data: data), let content = document.string else {
                throw HarnessError("PDF sem texto legível: \(filename)")
            }
            text = content
            classification = "document"
        } else {
            guard data.count <= 512_000, let content = String(data: data, encoding: .utf8), !content.contains("\0")
            else { throw HarnessError("Formato de anexo sem extração local: \(filename)") }
            text = content
            classification = "attachment"
        }
        guard text.utf8.count <= 512_000 else {
            throw HarnessError("Texto extraído muito grande. Selecione um trecho menor.")
        }
        var item = ContextItem()
        item.path = "attachments/" + filename
        item.hash = Coding.hash(data)
        item.content = ContextFirewall.redact(text)
        item.classification = classification
        item.estimatedTokens = (item.content.utf8.count + 3) / 4
        item.reason = "Fonte selecionada explicitamente; SHA-256 do arquivo original"
        item.score = 100
        return item
    }
}
