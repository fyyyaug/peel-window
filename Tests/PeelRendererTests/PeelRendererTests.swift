import Testing
import PeelCore
@testable import PeelRenderer

@Test("Grid topology has the expected vertex and triangle counts")
func meshTopology() {
    let mesh = PeelMesh(columns: 4, rows: 3)

    #expect(mesh.vertices.count == 12)
    #expect(mesh.indices.count == 36)
}

@Test("The selected corner receives more curl than its opposite corner")
func cornerCurlFalloff() {
    let mesh = PeelMesh(columns: 3, rows: 3)
    let pose = PeelPose(
        corner: .topRight,
        pull: PeelPoint(x: -0.6, y: -0.4),
        progress: 0.8,
        lift: 0.9
    )
    let vertices = mesh.deformed(for: pose)
    let bottomLeft = vertices[0]
    let topRight = vertices[8]

    #expect(topRight.position.z > bottomLeft.position.z)
    #expect(topRight.curl > 0.8)
    #expect(bottomLeft.curl == 0)
}
