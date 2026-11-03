import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import PeelCore

/// Builds the same page-curl transition for every starting corner. The filter
/// curls from the upper-right; mirrored inputs and output handle the others.
public enum PeelPageCurl {
    public static func image(
        front: CIImage,
        underneath: CIImage?,
        corner: PeelCorner,
        pull: PeelPoint,
        progress: Double,
        maximumSize: Double
    ) -> CIImage? {
        let extent = CGRect(origin: .zero, size: front.extent.size)
        guard extent.width > 0, extent.height > 0 else { return nil }

        let lower = underneath.map { aspectFill($0, in: extent) }
            ?? CIImage(color: CIColor(red: 0.055, green: 0.067, blue: 0.105))
                .cropped(to: extent)
        let backside = CIImage(color: CIColor(red: 0.92, green: 0.89, blue: 0.83))
            .cropped(to: extent)
        let orientation = transform(for: corner, in: extent)

        let filter = CIFilter.pageCurlWithShadowTransition()
        filter.inputImage = front.transformed(by: orientation).cropped(to: extent)
        filter.targetImage = lower.transformed(by: orientation).cropped(to: extent)
        filter.backsideImage = backside
        filter.extent = extent
        filter.shadowExtent = extent
        filter.angle = angle(for: corner, pull: pull)
        filter.radius = Float(min(extent.width, extent.height) * 0.20)
        filter.shadowAmount = 0.8
        filter.shadowSize = Float(min(extent.width, extent.height) * 0.025)
        filter.time = Float(progress.clamped(to: 0...1) * maximumSize.clamped(to: 0.1...1))

        return filter.outputImage?
            .transformed(by: orientation)
            .cropped(to: extent)
    }

    public static func transform(for corner: PeelCorner, in extent: CGRect) -> CGAffineTransform {
        let horizontalFlip = corner.unitPoint.x == 0
        let verticalFlip = corner.unitPoint.y == 0
        return CGAffineTransform(
            a: horizontalFlip ? -1 : 1,
            b: 0,
            c: 0,
            d: verticalFlip ? -1 : 1,
            tx: horizontalFlip ? extent.width : 0,
            ty: verticalFlip ? extent.height : 0
        )
    }

    public static func angle(for corner: PeelCorner, pull: PeelPoint) -> Float {
        let horizontal = corner.unitPoint.x == 0 ? max(pull.x, 0) : max(-pull.x, 0)
        let vertical = corner.unitPoint.y == 0 ? max(pull.y, 0) : max(-pull.y, 0)
        let direction = horizontal + vertical > 0.000_001
            ? atan2(vertical, horizontal) : .pi / 4
        return Float(Double.pi + direction)
    }

    private static func aspectFill(_ image: CIImage, in extent: CGRect) -> CIImage {
        let source = image.extent
        guard source.width > 0, source.height > 0 else { return image.cropped(to: extent) }
        let scale = max(extent.width / source.width, extent.height / source.height)
        let transform = CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: (extent.width - source.width * scale) / 2 - source.minX * scale,
            ty: (extent.height - source.height * scale) / 2 - source.minY * scale
        )
        return image.transformed(by: transform).cropped(to: extent)
    }
}
