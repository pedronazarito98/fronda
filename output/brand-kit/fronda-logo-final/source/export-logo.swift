import AppKit
import Vision
import CoreImage

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sourceURL = root.appendingPathComponent("source/wordmark-aprovado-v3.png")
let source = NSBitmapImageRep(data: try Data(contentsOf: sourceURL))!
let width = source.pixelsWide, height = source.pixelsHigh
let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(url: sourceURL)
try handler.perform([request])
guard let result = request.results?.first else { fatalError("Foreground not found") }
let buffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
let maskImage = CIImage(cvPixelBuffer: buffer)
let context = CIContext(options: [.workingColorSpace: NSNull()])
let bounds = CGRect(x: 0, y: 0, width: width, height: height)
let smoothed = maskImage.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3.0]).cropped(to: bounds)
let maskCG = context.createCGImage(smoothed, from: bounds)!
let mask = NSBitmapImageRep(cgImage: maskCG)
let master = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied, bytesPerRow: width * 4, bitsPerPixel: 32)!
let alphaOnly = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: width * 3, bitsPerPixel: 24)!
for y in 0..<height {
    for x in 0..<width {
        let src = y * source.bytesPerRow + x * (source.bitsPerPixel / 8)
        let dst = y * master.bytesPerRow + x * 4
        let value = Double(mask.bitmapData![y * mask.bytesPerRow + x * (mask.bitsPerPixel / 8)])
        let t = min(1, max(0, (value - 110) / 50))
        let alpha = UInt8((t * t * (3 - 2 * t) * 255).rounded())
        for channel in 0..<3 {
            master.bitmapData![dst + channel] = source.bitmapData![src + channel]
            alphaOnly.bitmapData![y * alphaOnly.bytesPerRow + x * 3 + channel] = alpha
        }
        master.bitmapData![dst + 3] = alpha
    }
}
func save(_ bitmap: NSBitmapImageRep, _ path: String) throws {
    try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(path))
}
try save(master, "master/fronda-logo-transparente.png")
try save(alphaOnly, "source/mascara-alpha.png")
let image = NSImage(size: NSSize(width: width, height: height))
image.addRepresentation(master)
func render(outputWidth: Int, background: NSColor? = nil) -> NSBitmapImageRep {
    let outputHeight = Int((Double(height) * Double(outputWidth) / Double(width)).rounded())
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: outputWidth, pixelsHigh: outputHeight, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: outputWidth * 4, bitsPerPixel: 32)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    let rect = NSRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
    if let background { background.setFill(); rect.fill() }
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
for size in [320, 640, 960, 1280, 1920] {
    try save(render(outputWidth: size), "web/fronda-logo-\(size).png")
}
try save(render(outputWidth: width, background: NSColor(srgbRed: 238/255, green: 232/255, blue: 218/255, alpha: 1)), "preview/fronda-logo-light.png")
try save(render(outputWidth: width, background: NSColor(srgbRed: 33/255, green: 31/255, blue: 27/255, alpha: 1)), "preview/fronda-logo-dark.png")
print("Exported \(width)x\(height). Foreground instances: \(result.allInstances.count).")
