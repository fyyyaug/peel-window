import MetalKit
import PeelCore

public struct PeelVertex: Equatable, Sendable {
    public var position: SIMD3<Float>
    public var textureCoordinate: SIMD2<Float>
    public var curl: Float

    public init(
        position: SIMD3<Float>,
        textureCoordinate: SIMD2<Float>,
        curl: Float = 0
    ) {
        self.position = position
        self.textureCoordinate = textureCoordinate
        self.curl = curl
    }
}

public struct PeelMesh: Sendable {
    public let columns: Int
    public let rows: Int
    public let vertices: [PeelVertex]
    public let indices: [UInt32]

    public init(columns: Int = 28, rows: Int = 20) {
        precondition(columns >= 2 && rows >= 2)
        self.columns = columns
        self.rows = rows

        var vertices: [PeelVertex] = []
        vertices.reserveCapacity(columns * rows)

        for row in 0..<rows {
            let v = Float(row) / Float(rows - 1)
            for column in 0..<columns {
                let u = Float(column) / Float(columns - 1)
                vertices.append(
                    PeelVertex(
                        position: SIMD3<Float>(u * 1.76 - 0.88, v * 1.44 - 0.72, 0),
                        textureCoordinate: SIMD2<Float>(u, v)
                    )
                )
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity((columns - 1) * (rows - 1) * 6)

        for row in 0..<(rows - 1) {
            for column in 0..<(columns - 1) {
                let topLeft = UInt32(row * columns + column)
                let topRight = topLeft + 1
                let bottomLeft = UInt32((row + 1) * columns + column)
                let bottomRight = bottomLeft + 1
                indices.append(contentsOf: [
                    topLeft, bottomLeft, topRight,
                    topRight, bottomLeft, bottomRight,
                ])
            }
        }

        self.vertices = vertices
        self.indices = indices
    }

    public func deformed(for pose: PeelPose) -> [PeelVertex] {
        vertices.map { vertex in
            var result = vertex
            let u = Double(vertex.textureCoordinate.x)
            let v = Double(vertex.textureCoordinate.y)
            let corner = pose.corner.unitPoint
            let distance = hypot(u - corner.x, v - corner.y)
            let linearInfluence = (1 - distance / 0.82).clamped(to: 0...1)
            let influence = linearInfluence * linearInfluence * (3 - 2 * linearInfluence)
            let curl = sin(influence * .pi / 2) * pose.lift

            result.position.x += Float(pose.pull.x * influence * 0.72)
            result.position.y += Float(pose.pull.y * influence * 0.72)
            result.position.z = Float(curl * 0.62)
            result.curl = Float(curl)
            return result
        }
    }
}

@MainActor
public final class PeelMetalRenderer: NSObject, MTKViewDelegate {
    public var pose: PeelPose = .flat {
        didSet { rebuildVertexBuffer() }
    }

    public private(set) var lastFrameDuration: TimeInterval = 0

    private let mesh: PeelMesh
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let snapshotPipelineState: MTLRenderPipelineState
    private let underlayPipelineState: MTLRenderPipelineState
    private let textureLoader: MTKTextureLoader
    private let indexBuffer: MTLBuffer
    private let flatVertexBuffer: MTLBuffer
    private var vertexBuffer: MTLBuffer?
    private var frontTexture: MTLTexture?
    private var underlayTexture: MTLTexture?

    public init?(view: MTKView, mesh: PeelMesh = .init()) {
        guard
            let device = view.device ?? MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue(),
            let shaderURL = Bundle.module.url(
                forResource: "PeelShaders.metal",
                withExtension: "txt"
            ),
            let shaderSource = try? String(contentsOf: shaderURL, encoding: .utf8),
            let library = try? device.makeLibrary(source: shaderSource, options: nil),
            let vertexFunction = library.makeFunction(name: "peelVertex"),
            let fragmentFunction = library.makeFunction(name: "peelFragment"),
            let snapshotFunction = library.makeFunction(name: "peelSnapshotFragment"),
            let underlayFunction = library.makeFunction(name: "peelUnderlayFragment")
        else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }
        descriptor.fragmentFunction = snapshotFunction
        guard let snapshotPipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }
        descriptor.fragmentFunction = underlayFunction
        guard
            let underlayPipelineState = try? device.makeRenderPipelineState(descriptor: descriptor),
            let indexBuffer = device.makeBuffer(
                bytes: mesh.indices,
                length: mesh.indices.count * MemoryLayout<UInt32>.stride
            ),
            let flatVertexBuffer = device.makeBuffer(
                bytes: mesh.vertices,
                length: mesh.vertices.count * MemoryLayout<PeelVertex>.stride
            )
        else {
            return nil
        }

        self.mesh = mesh
        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.snapshotPipelineState = snapshotPipelineState
        self.underlayPipelineState = underlayPipelineState
        self.textureLoader = MTKTextureLoader(device: device)
        self.indexBuffer = indexBuffer
        self.flatVertexBuffer = flatVertexBuffer
        super.init()

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.055, green: 0.067, blue: 0.105, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.delegate = self
        rebuildVertexBuffer()
    }

    public func showSnapshots(front: CGImage?, underneath: CGImage?) throws {
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.bottomLeft,
            .SRGB: false,
        ]
        let newFront = try front.map { try textureLoader.newTexture(cgImage: $0, options: options) }
        let newUnderlay = try underneath.map { try textureLoader.newTexture(cgImage: $0, options: options) }
        frontTexture = newFront
        underlayTexture = newUnderlay
    }

    public func draw(in view: MTKView) {
        let frameStart = CACurrentMediaTime()

        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let vertexBuffer,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        if let underlayTexture {
            encoder.setRenderPipelineState(underlayPipelineState)
            encoder.setVertexBuffer(flatVertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(underlayTexture, index: 0)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: mesh.indices.count,
                indexType: .uint32,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
        }

        encoder.setRenderPipelineState(frontTexture == nil ? pipelineState : snapshotPipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(frontTexture, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: mesh.indices.count,
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        lastFrameDuration = CACurrentMediaTime() - frameStart
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func rebuildVertexBuffer() {
        let vertices = mesh.deformed(for: pose)
        vertexBuffer = commandQueue.device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<PeelVertex>.stride
        )
    }
}

