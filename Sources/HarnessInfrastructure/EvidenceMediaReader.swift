import AVFoundation
import AppKit
import Foundation
import HarnessDomain
import ImageIO

public enum EvidenceMediaReader {
    /// Downsample before sending so a large source never becomes an unbounded provider payload.
    public static func imageContent(url: URL, second: Double = 0) async throws -> JSONValue {
        let image: CGImage
        var description = "Imagem observada."
        if ["mp4", "mov", "webm"].contains(url.pathExtension.lowercased()) {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration).seconds
            guard second.isFinite, second >= 0, duration.isFinite, second < duration else {
                throw HarnessError("Escolha um instante entre 0 e \(duration) segundos.")
            }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            generator.maximumSize = CGSize(width: 1600, height: 1600)
            let result = try await generator.image(at: CMTime(seconds: second, preferredTimescale: 600))
            image = result.image
            description =
                "Frame do vídeo em \(result.actualTime.seconds)s; duração \(duration)s. Apenas este frame foi fornecido, sem áudio."
        } else {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                    source, 0,
                    [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1600,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                    ] as CFDictionary)
            else { throw HarnessError("Imagem não pôde ser decodificada.") }
            image = thumbnail
        }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]),
            data.count <= 4_000_000
        else {
            throw HarnessError("Prévia excede o limite de envio.")
        }
        return .object([
            "content": .array([
                .object(["type": .string("text"), "text": .string(description)]),
                .object([
                    "type": .string("image"), "mimeType": .string("image/jpeg"),
                    "data": .string(data.base64EncodedString()),
                ]),
            ]), "isError": .bool(false),
        ])
    }
}
