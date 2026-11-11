import CoreGraphics
import CoreImage
import MetalKit
import Testing
import PeelCore
@testable import PeelRenderer

@Test("Grid topology has the expected vertex and triangle counts")
func meshTopology() {
    let mesh = PeelMesh(columns: 4, rows: 3)

    #expect(mesh.vertices.count == 12)
    #expect(mesh.indices.count == 36)
}

@Test("Each selected corner curls more than its opposite corner")
func everyCornerCurlFalloff() {
    let mesh = PeelMesh(columns: 3, rows: 3)
    let cases: [(PeelCorner, Int, Int, PeelPoint)] = [
        (.bottomLeft, 0, 8, PeelPoint(x: 0.5, y: 0.5)),
        (.bottomRight, 2, 6, PeelPoint(x: -0.5, y: 0.5)),
        (.topLeft, 6, 2, PeelPoint(x: 0.5, y: -0.5)),
        (.topRight, 8, 0, PeelPoint(x: -0.5, y: -0.5)),
    ]
    for (corner, selectedIndex, oppositeIndex, pull) in cases {
        let pose = PeelPose(corner: corner, pull: pull, progress: 0.8, lift: 0.9)
        let vertices = mesh.deformed(for: pose)
        #expect(vertices[selectedIndex].curl > 0.8)
        #expect(vertices[oppositeIndex].curl == 0)
        #expect(vertices[selectedIndex].position.z > vertices[oppositeIndex].position.z)
    }
}

@Test("A deep upper-corner peel spreads to the lower corner on the same edge")
func upperPeelReachesLowerCorner() {
    let mesh = PeelMesh(columns: 3, rows: 3)
    let shallow = PeelPose(
        corner: .topRight,
        pull: PeelPoint(x: -0.25, y: -0.25),
        progress: 0.25,
        lift: 0.4
    )
    let deep = PeelPose(
        corner: .topRight,
        pull: PeelPoint(x: -0.7, y: -0.7),
        progress: 1,
        lift: 1
    )
    let early = mesh.deformed(for: shallow)
    let late = mesh.deformed(for: deep)

    #expect(early[2].curl == 0)
    #expect(early[5].curl == 0)
    #expect(abs(Double(early[8].position.x) - 0.70) < 0.000_001)
    #expect(abs(Double(early[8].position.y) - 0.54) < 0.000_001)
    #expect(late[2].curl > 0.9)
    #expect(late[5].curl > 0.9)
    #expect(late[2].position.x < mesh.vertices[2].position.x)
    #expect(late[2].position.y > mesh.vertices[2].position.y)
    #expect(late[8].position.y < mesh.vertices[8].position.y)
    #expect(late[0].curl == 0)
}

@Test("A deep lower-corner peel also spreads upward on the same edge")
func lowerPeelReachesUpperCorner() {
    let mesh = PeelMesh(columns: 3, rows: 3)
    let pose = PeelPose(
        corner: .bottomLeft,
        pull: PeelPoint(x: 0.7, y: 0.7),
        progress: 1,
        lift: 1
    )
    let vertices = mesh.deformed(for: pose)
    #expect(vertices[6].curl > 0.9)
    #expect(vertices[6].position.x > mesh.vertices[6].position.x)
    #expect(vertices[6].position.y < mesh.vertices[6].position.y)
    #expect(vertices[0].position.y > mesh.vertices[0].position.y)
    #expect(vertices[8].curl == 0)
}

@Test("A released corner returns to exactly flat geometry")
func flatCornerGeometry() {
    let mesh = PeelMesh(columns: 5, rows: 4)
    #expect(mesh.deformed(for: .flat) == mesh.vertices)
}

@Test("Preview preserves landscape and portrait image proportions")
func previewKeepsAspectRatio() {
    let view = CGSize(width: 1000, height: 700)
    for image in [CGSize(width: 1600, height: 900), CGSize(width: 600, height: 1000)] {
        let layout = PeelPreviewLayout(viewSize: view, imageSize: image)
        let displayedAspect = (layout.halfWidth * Double(view.width)) /
            (layout.halfHeight * Double(view.height))
        let imageAspect = Double(image.width / image.height)

        #expect(abs(displayedAspect - imageAspect) < 0.000_001)
        #expect(layout.halfWidth <= 0.88)
        #expect(layout.halfHeight <= 0.72)
        let corner = layout.corner(.topRight, in: view)
        #expect(corner.x > view.width / 2 && corner.y > view.height / 2)
    }
}

@Test("Desktop layout covers the source window instead of shrinking it")
func desktopFillsWindow() {
    let size = CGSize(width: 1200, height: 800)
    let layout = PeelPreviewLayout(
        viewSize: size,
        imageSize: CGSize(width: 2400, height: 1600),
        fillsView: true
    )

    #expect(layout.halfWidth == 1)
    #expect(layout.halfHeight == 1)
    #expect(layout.corner(.topLeft, in: size) == CGPoint(x: 0, y: 800))
    #expect(layout.corner(.topRight, in: size) == CGPoint(x: 1200, y: 800))
}

@Test("Every corner maps to the corresponding preview corner")
func previewCorners() {
    let size = CGSize(width: 1000, height: 700)
    let layout = PeelPreviewLayout(viewSize: size, imageSize: CGSize(width: 800, height: 500))
    let topLeft = layout.corner(.topLeft, in: size)
    let topRight = layout.corner(.topRight, in: size)
    let bottomLeft = layout.corner(.bottomLeft, in: size)
    let bottomRight = layout.corner(.bottomRight, in: size)

    #expect(topLeft.x == bottomLeft.x)
    #expect(topRight.x == bottomRight.x)
    #expect(topLeft.y == topRight.y)
    #expect(bottomLeft.y == bottomRight.y)
    #expect(topLeft.x < topRight.x)
    #expect(bottomLeft.y < topLeft.y)
}

@Test("Maximum peel size limits the affected area")
func maximumPeelReach() {
    let mesh = PeelMesh(columns: 11, rows: 11)
    let pose = PeelPose(
        corner: .topRight,
        pull: PeelPoint(x: -0.5, y: -0.5),
        progress: 1,
        lift: 1
    )
    let small = mesh.deformed(for: pose, maximumReach: 0.2)
    let large = mesh.deformed(for: pose, maximumReach: 0.8)
    let pointInsideLargeOnly = 10 * 11 + 5
    #expect(small[pointInsideLargeOnly].curl == 0)
    #expect(large[pointInsideLargeOnly].curl > 0)
}

@Test("Native page curl renders a front and lower image for every corner")
func nativePageCurlRenders() {
    let extent = CGRect(x: 0, y: 0, width: 128, height: 80)
    let front = CIImage(color: CIColor(red: 0.2, green: 0.7, blue: 0.7)).cropped(to: extent)
    let lower = CIImage(color: CIColor(red: 0.9, green: 0.4, blue: 0.2)).cropped(to: extent)
    let context = CIContext()

    for corner in PeelCorner.allCases {
        let output = PeelPageCurl.image(
            front: front,
            underneath: lower,
            corner: corner,
            pull: PeelPoint(
                x: corner.unitPoint.x == 0 ? 0.5 : -0.5,
                y: corner.unitPoint.y == 0 ? 0.5 : -0.5
            ),
            progress: 0.5,
            maximumSize: 1
        )
        #expect(output?.extent == extent)
        if let output {
            #expect(context.createCGImage(output, from: extent) != nil)
        }
    }
}

@Test("The desktop background shows through transparent window corners")
@MainActor
func desktopCornerTransparency() throws {
    let width = 128
    let height = 80
    let extent = CGRect(x: 0, y: 0, width: width, height: height)
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let view = MTKView(frame: extent, device: device)
    let renderer = try #require(PeelMetalRenderer(view: view))
    renderer.fillsView = true
    renderer.highlightedCorners = []
    renderer.mtkView(view, drawableSizeWillChange: extent.size)

    let context = CIContext()
    let edge = CIImage(color: CIColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        .cropped(to: extent.insetBy(dx: 6, dy: 6))
    let center = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
        .cropped(to: extent.insetBy(dx: 12, dy: 12))
    let background = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: extent)
    let front = try #require(context.createCGImage(center.composited(over: edge), from: extent))
    let lower = try #require(context.createCGImage(background, from: extent))
    try renderer.showSnapshots(front: front, underneath: lower)

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
    )
    textureDescriptor.storageMode = .shared
    textureDescriptor.usage = .renderTarget
    let texture = try #require(device.makeTexture(descriptor: textureDescriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store

    let cornerPixels = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    for progress in [0.0, 0.05, 0.0] {
        renderer.pose = PeelPose(corner: .topRight, pull: PeelPoint(x: -0.3, y: -0.3),
                                 progress: progress, lift: progress)
        let commands = try #require(queue.makeCommandBuffer())
        try #require(renderer.encodeFrame(to: pass, commandBuffer: commands))
        commands.commit()
        commands.waitUntilCompleted()
        try #require(commands.status == .completed)

        for (x, y) in cornerPixels {
            var pixel = [UInt8](repeating: 0, count: 4)
            texture.getBytes(&pixel, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
            #expect(pixel[0] > 180 && pixel[1] < 15 && pixel[2] < 15 && pixel[3] == 255)
        }
        if progress == 0 {
            var edgePixel = [UInt8](repeating: 0, count: 4)
            texture.getBytes(&edgePixel, bytesPerRow: 4,
                             from: MTLRegionMake2D(8, height / 2, 1, 1), mipmapLevel: 0)
            #expect((126...129).contains(edgePixel[0]))
            #expect((126...129).contains(edgePixel[2]))
        }
    }
}

@Test("Page curl direction follows horizontal and vertical pointer travel")
func pageCurlAngleFollowsPull() {
    for corner in PeelCorner.allCases {
        let x = corner.unitPoint.x == 0 ? 1.0 : -1.0
        let y = corner.unitPoint.y == 0 ? 1.0 : -1.0
        let sideAngle = PeelPageCurl.angle(for: corner, pull: PeelPoint(x: x, y: 0))
        let diagonalAngle = PeelPageCurl.angle(for: corner, pull: PeelPoint(x: x, y: y))
        let topAngle = PeelPageCurl.angle(for: corner, pull: PeelPoint(x: 0, y: y))
        #expect(abs(sideAngle - Float.pi) < 0.000_001)
        #expect(sideAngle < diagonalAngle)
        #expect(diagonalAngle < topAngle)
        #expect(abs(topAngle - Float.pi * 1.5) < 0.000_001)
    }
}

@Test("Page curl mirrors its upper-right origin to the selected corner")
func pageCurlCornerTransforms() {
    let extent = CGRect(x: 0, y: 0, width: 128, height: 80)
    let upperRight = CGPoint(x: extent.width, y: extent.height)
    let expected: [PeelCorner: CGPoint] = [
        .topLeft: CGPoint(x: 0, y: 80),
        .topRight: CGPoint(x: 128, y: 80),
        .bottomLeft: CGPoint(x: 0, y: 0),
        .bottomRight: CGPoint(x: 128, y: 0),
    ]
    for (corner, point) in expected {
        #expect(upperRight.applying(PeelPageCurl.transform(for: corner, in: extent)) == point)
    }
}

@Test("Lower snapshot uses centered cropping instead of stretching")
func lowerSnapshotAspectFill() {
    let wider = PeelTextureMapping(
        sourceSize: CGSize(width: 2000, height: 1000),
        destinationSize: CGSize(width: 1000, height: 1000)
    )
    #expect(wider.scaleX == 0.5)
    #expect(wider.scaleY == 1)
    #expect(wider.offsetX == 0.25)

    let taller = PeelTextureMapping(
        sourceSize: CGSize(width: 1000, height: 2000),
        destinationSize: CGSize(width: 1000, height: 1000)
    )
    #expect(taller.scaleX == 1)
    #expect(taller.scaleY == 0.5)
    #expect(taller.offsetY == 0.25)
}
