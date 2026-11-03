import CoreGraphics
import Testing
import PeelCore
@testable import PeelRenderer

@Test("Grid topology has the expected vertex and triangle counts")
func meshTopology() {
    let mesh = PeelMesh(columns: 4, rows: 3)

    #expect(mesh.vertices.count == 12)
    #expect(mesh.indices.count == 36)
}

@Test("A right-hand page turn keeps the whole left edge on its spine")
func rightPageTurnHinge() {
    let mesh = PeelMesh(columns: 3, rows: 3)
    let pose = PeelPose(
        corner: .topRight,
        pull: PeelPoint(x: -0.6, y: -0.4),
        progress: 0.8,
        lift: 0.9
    )
    let vertices = mesh.deformed(for: pose)
    let bottomLeft = vertices[0]
    let topLeft = vertices[6]
    let bottomRight = vertices[2]
    let topRight = vertices[8]

    #expect(bottomLeft.position.x == mesh.vertices[0].position.x)
    #expect(topLeft.position.x == mesh.vertices[6].position.x)
    #expect(bottomRight.position.x == topRight.position.x)
    #expect(bottomRight.position.z > bottomLeft.position.z)
    #expect(topRight.position.z == bottomRight.position.z)
}

@Test("A left-hand page turn keeps the whole right edge on its spine")
func leftPageTurnHinge() {
    let mesh = PeelMesh(columns: 3, rows: 3)
    let pose = PeelPose(corner: .bottomLeft, pull: .zero, progress: 0.5, lift: 1)
    let vertices = mesh.deformed(for: pose)
    #expect(vertices[2].position.x == mesh.vertices[2].position.x)
    #expect(vertices[8].position.x == mesh.vertices[8].position.x)
    #expect(vertices[0].position.x > mesh.vertices[0].position.x)
    #expect(vertices[6].position.x == vertices[0].position.x)
}

@Test("A released page returns to exactly flat geometry")
func flatPageGeometry() {
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

@Test("Maximum page turn percentage limits rotation of the whole sheet")
func maximumPageTurn() {
    let mesh = PeelMesh(columns: 3, rows: 3)
    let pose = PeelPose(
        corner: .topRight,
        pull: PeelPoint(x: -0.5, y: -0.5),
        progress: 1,
        lift: 1
    )
    let small = mesh.deformed(for: pose, maximumTurn: 0.2)
    let large = mesh.deformed(for: pose, maximumTurn: 0.8)
    #expect(small[2].position.x > large[2].position.x)
    #expect(small[2].curl < large[2].curl)
    #expect(large[2].position.x < mesh.vertices[0].position.x)
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
