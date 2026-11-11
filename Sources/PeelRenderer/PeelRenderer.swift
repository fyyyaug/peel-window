import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit
import PeelCore

public enum PeelRendererError: Error {
    case pageCurlTextureUnavailable
}

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

    /// A corner starts the curl; dragging farther carries one continuous
    /// rolled edge toward the other corner rather than creating two flaps.
    public func deformed(for pose: PeelPose, maximumReach: Double = 0.82) -> [PeelVertex] {
        let reach = maximumReach.clamped(to: 0.1...1)
        let verticalCoverage = min(pose.progress * 1.15, 1)
        let transitionWidth = 0.18
        return vertices.map { vertex in
            var result = vertex
            let u = Double(vertex.textureCoordinate.x)
            let v = Double(vertex.textureCoordinate.y)
            let corner = pose.corner.unitPoint
            let horizontalDistance = abs(u - corner.x)
            let verticalDistance = abs(v - corner.y)
            let horizontalLinear = (1 - horizontalDistance / reach).clamped(to: 0...1)
            let horizontalInfluence = horizontalLinear * horizontalLinear
                * (3 - 2 * horizontalLinear)
            let verticalLinear = ((verticalCoverage + transitionWidth - verticalDistance)
                / transitionWidth).clamped(to: 0...1)
            let verticalInfluence = verticalLinear * verticalLinear * (3 - 2 * verticalLinear)
            let influence = horizontalInfluence * verticalInfluence
            let curl = sin(influence * .pi / 2) * pose.lift

            result.position.x += Float(pose.pull.x * influence * 0.72 * reach / 0.82)
            let verticalDirection = 1 - 2 * verticalDistance
            result.position.y += Float(pose.pull.y * influence * verticalDirection * 0.72 * reach / 0.82)
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
    public var maximumReach: Double = 0.82 {
        didSet { rebuildVertexBuffer() }
    }
    public var highlightedCorners: Set<PeelCorner> = [.topRight]
    public var fillsView = false {
        didSet { updateLayout() }
    }

    public private(set) var lastFrameDuration: TimeInterval = 0

    private let mesh: PeelMesh
    private let preservesWindowShape: Bool
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let snapshotPipelineState: MTLRenderPipelineState
    private let underlayPipelineState: MTLRenderPipelineState
    private let textureLoader: MTKTextureLoader
    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let indexBuffer: MTLBuffer
    private var flatVertexBuffer: MTLBuffer?
    private var vertexBuffer: MTLBuffer?
    private var frontTexture: MTLTexture?
    private var underlayTexture: MTLTexture?
    private var frontCIImage: CIImage?
    private var underlayCIImage: CIImage?
    private var pageCurlTexture: MTLTexture?
    private var imageSize = CGSize(width: 800, height: 500)
    private var underlaySize = CGSize(width: 800, height: 500)
    private var drawableSize = CGSize(width: 1, height: 1)
    private var previewLayout: PeelPreviewLayout?

    public init?(view: MTKView, mesh: PeelMesh = .init(), preservesWindowShape: Bool = false) {
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
        let snapshotAttachment = descriptor.colorAttachments[0]!
        snapshotAttachment.isBlendingEnabled = true
        // Window snapshots carry premultiplied color, including at rounded edges.
        snapshotAttachment.sourceRGBBlendFactor = .one
        snapshotAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        snapshotAttachment.sourceAlphaBlendFactor = .one
        snapshotAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        guard let snapshotPipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }
        snapshotAttachment.isBlendingEnabled = false
        descriptor.fragmentFunction = underlayFunction
        guard
            let underlayPipelineState = try? device.makeRenderPipelineState(descriptor: descriptor),
            let indexBuffer = device.makeBuffer(
                bytes: mesh.indices,
                length: mesh.indices.count * MemoryLayout<UInt32>.stride
            )
        else {
            return nil
        }

        self.mesh = mesh
        self.preservesWindowShape = preservesWindowShape
        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.snapshotPipelineState = snapshotPipelineState
        self.underlayPipelineState = underlayPipelineState
        self.textureLoader = MTKTextureLoader(device: device)
        self.ciContext = CIContext(mtlDevice: device)
        self.indexBuffer = indexBuffer
        super.init()

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        if preservesWindowShape {
            view.layer?.isOpaque = false
            view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        } else {
            view.clearColor = MTLClearColor(red: 0.055, green: 0.067, blue: 0.105, alpha: 1)
        }
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.delegate = self
        drawableSize = view.drawableSize
        updateLayout()
    }

    public func corner(_ corner: PeelCorner, in viewSize: CGSize) -> CGPoint {
        PeelPreviewLayout(viewSize: viewSize, imageSize: imageSize, fillsView: fillsView)
            .corner(corner, in: viewSize)
    }

    public func showSnapshots(front: CGImage?, underneath: CGImage?) throws {
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.bottomLeft,
            .SRGB: false,
        ]
        let newFront = try front.map { try textureLoader.newTexture(cgImage: $0, options: options) }
        let newUnderlay = try underneath.map { try textureLoader.newTexture(cgImage: $0, options: options) }
        let newPageCurlTexture: MTLTexture?
        if let front {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: front.width,
                height: front.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            guard let texture = commandQueue.device.makeTexture(descriptor: descriptor) else {
                throw PeelRendererError.pageCurlTextureUnavailable
            }
            newPageCurlTexture = texture
        } else {
            newPageCurlTexture = nil
        }
        frontTexture = newFront
        underlayTexture = newUnderlay
        frontCIImage = front.map(CIImage.init(cgImage:))
        underlayCIImage = underneath.map(CIImage.init(cgImage:))
        pageCurlTexture = newPageCurlTexture
        imageSize = front.map { CGSize(width: $0.width, height: $0.height) }
            ?? CGSize(width: 800, height: 500)
        underlaySize = underneath.map { CGSize(width: $0.width, height: $0.height) }
            ?? imageSize
        updateLayout()
    }

    public func draw(in view: MTKView) {
        let frameStart = CACurrentMediaTime()

        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            encodeFrame(to: descriptor, commandBuffer: commandBuffer)
        else {
            return
        }
        if view.presentsWithTransaction {
            commandBuffer.commit()
            commandBuffer.waitUntilScheduled()
            drawable.present()
        } else {
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        lastFrameDuration = CACurrentMediaTime() - frameStart
    }

    func encodeFrame(to descriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) -> Bool {
        guard let vertexBuffer else { return false }
        var renderedPageCurl = false
        if let frontCIImage, let pageCurlTexture, pose.progress > 0.001,
           let output = PeelPageCurl.image(
                front: frontCIImage,
                underneath: underlayCIImage,
                corner: pose.corner,
                pull: pose.pull,
                progress: pose.progress,
                maximumSize: maximumReach
           ) {
            let bounds = CGRect(x: 0, y: 0, width: pageCurlTexture.width, height: pageCurlTexture.height)
            var frame = output
            if preservesWindowShape {
                // Clip the complete curl, including the lower snapshot and paper backside,
                // to the source window's stationary silhouette.
                let clip = CIFilter.blendWithAlphaMask()
                clip.inputImage = output
                clip.backgroundImage = CIImage.empty().cropped(to: bounds)
                clip.maskImage = frontCIImage
                guard let clipped = clip.outputImage else { return false }
                frame = clipped
            }
            ciContext.render(
                frame,
                to: pageCurlTexture,
                commandBuffer: commandBuffer,
                bounds: bounds,
                colorSpace: colorSpace
            )
            renderedPageCurl = true
        }
        guard !preservesWindowShape || renderedPageCurl else { return false }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return false
        }

        if renderedPageCurl, let pageCurlTexture, let flatVertexBuffer {
            var identityMapping = SIMD4<Float>(1, 1, 0, 0)
            encoder.setRenderPipelineState(underlayPipelineState)
            encoder.setVertexBuffer(flatVertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(pageCurlTexture, index: 0)
            encoder.setFragmentBytes(
                &identityMapping,
                length: MemoryLayout<SIMD4<Float>>.stride,
                index: 0
            )
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: mesh.indices.count,
                indexType: .uint32,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
            encoder.endEncoding()
            return true
        }

        if let underlayTexture, let flatVertexBuffer {
            var mapping = PeelTextureMapping(
                sourceSize: underlaySize,
                destinationSize: imageSize
            ).shaderValue
            encoder.setRenderPipelineState(underlayPipelineState)
            encoder.setVertexBuffer(flatVertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(underlayTexture, index: 0)
            encoder.setFragmentBytes(
                &mapping,
                length: MemoryLayout<SIMD4<Float>>.stride,
                index: 0
            )
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
        var cornerMask = SIMD4<Float>(
            highlightedCorners.contains(.topLeft) ? 1 : 0,
            highlightedCorners.contains(.topRight) ? 1 : 0,
            highlightedCorners.contains(.bottomLeft) ? 1 : 0,
            highlightedCorners.contains(.bottomRight) ? 1 : 0
        )
        encoder.setFragmentBytes(
            &cornerMask,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 0
        )
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: mesh.indices.count,
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
        return true
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = size
        updateLayout()
    }

    private func updateLayout() {
        let layout = PeelPreviewLayout(viewSize: drawableSize, imageSize: imageSize,
                                       fillsView: fillsView)
        guard previewLayout != layout else { return }
        previewLayout = layout
        let vertices = mesh.vertices.map { vertex in
            var result = vertex
            result.position = layout.position(vertex.position)
            return result
        }
        flatVertexBuffer = commandQueue.device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<PeelVertex>.stride
        )
        rebuildVertexBuffer()
    }

    private func rebuildVertexBuffer() {
        guard let previewLayout else { return }
        let vertices = mesh.deformed(for: pose, maximumReach: maximumReach).map { vertex in
            var result = vertex
            result.position = previewLayout.position(vertex.position)
            return result
        }
        vertexBuffer = commandQueue.device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<PeelVertex>.stride
        )
    }
}

