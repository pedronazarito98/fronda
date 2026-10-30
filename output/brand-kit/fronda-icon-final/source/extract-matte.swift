import AppKit
import Vision
import CoreImage

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let source = root.appendingPathComponent("source/approved-icon.png")
let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(url: source)
try handler.perform([request])
guard let result = request.results?.first else { fatalError("No foreground mask") }
let buffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
let ci = CIImage(cvPixelBuffer: buffer)
let context = CIContext()
try context.writePNGRepresentation(of: ci, to: root.appendingPathComponent("source/foreground-matte.png"), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
print("Foreground instances: \(result.allInstances.count); matte: \(CVPixelBufferGetWidth(buffer)) × \(CVPixelBufferGetHeight(buffer))")
