import AppKit
import JavaScriptCore
import MetalKit

@MainActor
enum MascotResources {
    static var directory: URL? { Bundle.main.resourceURL?.appendingPathComponent("FrondaAnimation") }
    static let image: NSImage? = directory.flatMap { NSImage(contentsOf: $0.appendingPathComponent("mascot.png")) }
    static let graphics = try? MascotGraphics()

    static func data(_ name: String) throws -> Data {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        return try Data(contentsOf: directory.appendingPathComponent(name))
    }
}

@MainActor
final class MascotGraphics {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let texture: MTLTexture
    let vertices: MTLBuffer
    let indices: MTLBuffer
    let indexCount: Int

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw CocoaError(.featureUnsupported)
        }
        self.device = device
        self.queue = queue
        let source = String(decoding: try MascotResources.data("mascot.metal.txt"), as: UTF8.self)
        let library = try device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "mascotVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "mascotFragment")
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = .bgra8Unorm
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        texture = try MTKTextureLoader(device: device).newTexture(
            data: MascotResources.data("mascot.png"), options: [.SRGB: false, .origin: MTKTextureLoader.Origin.topLeft])
        let vertexData = try MascotResources.data("vertices.bin")
        let indexData = try MascotResources.data("indices.bin")
        guard
            let vertices = vertexData.withUnsafeBytes({ bytes in
                bytes.baseAddress.flatMap { device.makeBuffer(bytes: $0, length: bytes.count) }
            }),
            let indices = indexData.withUnsafeBytes({ bytes in
                bytes.baseAddress.flatMap { device.makeBuffer(bytes: $0, length: bytes.count) }
            })
        else { throw CocoaError(.featureUnsupported) }
        self.vertices = vertices
        self.indices = indices
        indexCount = indexData.count / MemoryLayout<UInt16>.stride
    }
}

@MainActor
final class MascotMotionEngine {
    private let context: JSContext
    private let configure: JSValue
    private let advance: JSValue
    private let touch: JSValue

    init?() {
        guard let context = JSContext(), let data = try? MascotResources.data("motion.js") else { return nil }
        context.evaluateScript(String(decoding: data, as: UTF8.self))
        guard context.exception == nil,
            let configure = context.objectForKeyedSubscript("configureMascot"), !configure.isUndefined,
            let advance = context.objectForKeyedSubscript("mascotFrame"), !advance.isUndefined,
            let touch = context.objectForKeyedSubscript("touchMascot"), !touch.isUndefined
        else { return nil }
        self.context = context
        self.configure = configure
        self.advance = advance
        self.touch = touch
    }

    func frame(
        delta: Double, state: String, reduced: Bool, pointer: CGPoint, hover: Int, velocity: CGPoint, dragging: Bool
    ) -> [Float]? {
        configure.call(withArguments: [state, reduced, pointer.x, pointer.y, hover, velocity.x, velocity.y, dragging])
        let count = max(1, Int(ceil(delta / 0.025)))
        var value: JSValue?
        for _ in 0..<count { value = advance.call(withArguments: [min(delta / Double(count), 0.025)]) }
        guard context.exception == nil, let numbers = value?.toArray() as? [NSNumber], numbers.count == 64 else {
            return nil
        }
        let frame = numbers.map(\.floatValue)
        return frame.allSatisfy(\.isFinite) ? frame : nil
    }

    func touch(branch: Int) { touch.call(withArguments: [branch]) }
}
