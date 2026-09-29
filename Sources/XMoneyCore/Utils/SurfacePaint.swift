import UIKit

/// Waits until a view has a real size, and until a PassKit button has committed
/// visible pixels. A transparent `layer.contents` does not count: on iOS 26 the
/// button installs a blank image first and fills the mark in later. Gives up
/// after a short wall-clock cap so a view that never lands in a window cannot
/// hold the loading surface open.
@MainActor
package enum SurfacePaint {
    package static func waitUntilButtonDrawn(_ button: UIView, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Task.isCancelled { return }
            button.layoutIfNeeded()
            button.layer.displayIfNeeded()
            if button.window != nil,
               button.bounds.width > 1,
               button.bounds.height > 1,
               hasVisibleMark(button) {
                return
            }
            do {
                try await Task.sleep(nanoseconds: 16_000_000)
            } catch {
                return
            }
        }
    }

    package static func waitUntilLaidOut(_ view: UIView, maxTurns: Int = 30) async {
        for _ in 0..<maxTurns {
            if Task.isCancelled { return }
            view.layoutIfNeeded()
            if view.bounds.width > 1, view.bounds.height > 1 {
                return
            }
            await nextTurn()
        }
    }

    private static func hasVisibleMark(_ view: UIView) -> Bool {
        if view.isHidden || view.alpha <= 0.01 { return false }
        if layerHasInk(view.layer) { return true }
        if let imageView = view as? UIImageView, imageHasInk(imageView.image) { return true }
        return view.subviews.contains(where: hasVisibleMark)
    }

    private static func layerHasInk(_ layer: CALayer) -> Bool {
        if let contents = layer.contents, contentsHaveInk(contents) { return true }
        return layer.sublayers?.contains(where: layerHasInk) ?? false
    }

    private static func contentsHaveInk(_ contents: Any) -> Bool {
        if let image = contents as? UIImage { return imageHasInk(image) }
        guard let object = contents as AnyObject? else { return false }
        // `as? CGImage` is rejected: a conditional cast to a CoreFoundation type always succeeds.
        guard CFGetTypeID(object) == CGImage.typeID else { return false }
        return cgImageHasInk(unsafeBitCast(object, to: CGImage.self))
    }

    private static func imageHasInk(_ image: UIImage?) -> Bool {
        guard let image, image.size.width > 1, image.size.height > 1 else { return false }
        if let cgImage = image.cgImage { return cgImageHasInk(cgImage) }
        return true
    }

    /// True when the bitmap has a non-transparent pixel. The iOS 26 placeholder
    /// image is a full-size CGImage with zero alpha, so a nil check is not enough.
    private static func cgImageHasInk(_ image: CGImage) -> Bool {
        guard image.width > 0, image.height > 0 else { return false }
        let width = 8
        let height = 8
        let bytesPerRow = width * 4
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: height * bytesPerRow, alignment: 16)
        defer { buffer.deallocate() }
        guard let context = CGContext(
            data: buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = buffer.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
        for index in stride(from: 3, to: height * bytesPerRow, by: 4) where pixels[index] > 16 {
            return true
        }
        return false
    }

    private static func nextTurn() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}
