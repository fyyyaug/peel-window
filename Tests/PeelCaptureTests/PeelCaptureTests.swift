import CoreGraphics
import CoreImage
import Testing
@testable import PeelCapture

@Test("Switching between two windows excludes the correct upper stack")
func switchingSourceWindows() {
    let stack: [CGWindowID] = [90, 11, 22, 33]
    #expect(PeelDesktopStack.excludedWindowIDs(sourceID: 11, frontToBack: stack) == [90, 11])
    #expect(PeelDesktopStack.excludedWindowIDs(sourceID: 22, frontToBack: stack) == [90, 11, 22])
    #expect(!PeelDesktopStack.excludedWindowIDs(sourceID: 22, frontToBack: stack).contains(33))
    let reordered: [CGWindowID] = [90, 22, 11, 33]
    #expect(PeelDesktopStack.excludedWindowIDs(sourceID: 22, frontToBack: reordered) == [90, 22])
}

@Test("Each source window uses its own position and dimensions for cropping")
func switchingSourceCrop() {
    let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let pixels = CGSize(width: 2000, height: 1600)
    let first = PeelDesktopCrop(displayFrame: display,
        sourceFrame: CGRect(x: 100, y: 200, width: 300, height: 100), displayPixels: pixels)
    let second = PeelDesktopCrop(displayFrame: display,
        sourceFrame: CGRect(x: 500, y: 50, width: 400, height: 600), displayPixels: pixels)
    #expect(first.pixelRect == CGRect(x: 200, y: 1000, width: 600, height: 200))
    #expect(second.pixelRect == CGRect(x: 1000, y: 300, width: 800, height: 1200))
}

@Test("Desktop crop maps a top-left screen window into display pixels")
func desktopCropCoordinates() {
    let crop = PeelDesktopCrop(
        displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        sourceFrame: CGRect(x: 100, y: 200, width: 300, height: 100),
        displayPixels: CGSize(width: 2000, height: 1600)
    )
    #expect(crop.pixelRect == CGRect(x: 200, y: 1000, width: 600, height: 200))
}

@Test("Desktop crop keeps only the pixels behind the selected source frame")
func desktopCropPixels() throws {
    let context = CIContext()
    let displayExtent = CGRect(x: 0, y: 0, width: 10, height: 10)
    let background = CIImage(color: CIColor(red: 0, green: 0, blue: 1))
        .cropped(to: displayExtent)
    let expectedWindow = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
        .cropped(to: CGRect(x: 5, y: 3, width: 2, height: 2))
    let display = try #require(context.createCGImage(
        expectedWindow.composited(over: background),
        from: displayExtent
    ))
    let cropped = try #require(PeelDesktopCrop.image(
        display,
        displayFrame: displayExtent,
        sourceFrame: CGRect(x: 5, y: 5, width: 2, height: 2),
        outputSize: CGSize(width: 2, height: 2)
    ))
    var pixels = [UInt8](repeating: 0, count: 2 * 2 * 4)
    pixels.withUnsafeMutableBytes { bytes in
        context.render(
            CIImage(cgImage: cropped),
            toBitmap: bytes.baseAddress!,
            rowBytes: 2 * 4,
            bounds: CGRect(x: 0, y: 0, width: 2, height: 2),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
    }
    #expect(stride(from: 0, to: pixels.count, by: 4).allSatisfy { pixels[$0] > 200 })
    #expect(stride(from: 2, to: pixels.count, by: 4).allSatisfy { pixels[$0] < 50 })
}
