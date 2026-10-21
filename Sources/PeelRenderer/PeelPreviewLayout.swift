import CoreGraphics

/// Keeps a captured window's proportions inside the preview's safe drawing area.
public struct PeelPreviewLayout: Equatable, Sendable {
    public let halfWidth: Double
    public let halfHeight: Double

    public init(viewSize: CGSize, imageSize: CGSize) {
        let viewWidth = max(Double(viewSize.width), 1)
        let viewHeight = max(Double(viewSize.height), 1)
        let imageWidth = max(Double(imageSize.width), 1)
        let imageHeight = max(Double(imageSize.height), 1)
        let imageAspect = imageWidth / imageHeight

        let widthIfHeightLimited = 0.72 * imageAspect * viewHeight / viewWidth
        if widthIfHeightLimited <= 0.88 {
            halfWidth = widthIfHeightLimited
            halfHeight = 0.72
        } else {
            halfWidth = 0.88
            halfHeight = 0.88 * viewWidth / (imageAspect * viewHeight)
        }
    }

    public func topRightCorner(in viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: Double(viewSize.width) * (1 + halfWidth) / 2,
            y: Double(viewSize.height) * (1 + halfHeight) / 2
        )
    }

    func position(_ point: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            point.x * Float(halfWidth / 0.88),
            point.y * Float(halfHeight / 0.72),
            point.z
        )
    }
}

/// Aspect-fills a lower snapshot without stretching it into the upper window's shape.
public struct PeelTextureMapping: Equatable, Sendable {
    public let scaleX: Float
    public let scaleY: Float
    public let offsetX: Float
    public let offsetY: Float

    public init(sourceSize: CGSize, destinationSize: CGSize) {
        let sourceAspect = max(Double(sourceSize.width), 1) / max(Double(sourceSize.height), 1)
        let destinationAspect = max(Double(destinationSize.width), 1) / max(Double(destinationSize.height), 1)
        if sourceAspect > destinationAspect {
            scaleX = Float(destinationAspect / sourceAspect)
            scaleY = 1
        } else {
            scaleX = 1
            scaleY = Float(sourceAspect / destinationAspect)
        }
        offsetX = (1 - scaleX) / 2
        offsetY = (1 - scaleY) / 2
    }

    var shaderValue: SIMD4<Float> {
        SIMD4<Float>(scaleX, scaleY, offsetX, offsetY)
    }
}
