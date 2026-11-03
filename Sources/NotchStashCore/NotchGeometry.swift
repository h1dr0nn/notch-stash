import CoreGraphics

/// Pure geometry helpers for placing the notch window and cursor panel (notch measurement adapted from NotchDrop, MIT).
public enum NotchGeometry {
    public static func notchRect(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        leftAuxWidth: CGFloat?,
        rightAuxWidth: CGFloat?
    ) -> CGRect? {
        guard safeAreaTop > 0, let left = leftAuxWidth, let right = rightAuxWidth, left > 0, right > 0 else {
            return nil
        }
        return CGRect(
            x: screenFrame.minX + left,
            y: screenFrame.maxY - safeAreaTop,
            width: screenFrame.width - left - right,
            height: safeAreaTop
        )
    }

    public static func topCenteredRect(in screenFrame: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    public static func panelOrigin(
        cursor: CGPoint,
        panelSize: CGSize,
        visibleFrame: CGRect,
        offset: CGFloat = 16
    ) -> CGPoint {
        var origin = CGPoint(x: cursor.x + offset, y: cursor.y - offset - panelSize.height)
        if origin.x + panelSize.width > visibleFrame.maxX {
            origin.x = cursor.x - offset - panelSize.width
        }
        if origin.y < visibleFrame.minY {
            origin.y = cursor.y + offset
        }
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - panelSize.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - panelSize.height)
        origin.x = min(max(origin.x, visibleFrame.minX), maxX)
        origin.y = min(max(origin.y, visibleFrame.minY), maxY)
        return origin
    }
}
