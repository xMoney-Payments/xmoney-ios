import CoreGraphics

/// Where to scroll so a focused field sits above the keyboard.
package enum KeyboardScroll {
    /// Rects are in the scroll view's bounds coordinate space, the same space as
    /// `convert(_:to: scrollView)`. Returns nil when the field is already in view
    /// or the content cannot move any further.
    package static func targetOffset(
        fieldRect: CGRect,
        bounds: CGRect,
        contentSize: CGSize,
        contentOffset: CGPoint,
        keyboardFrame: CGRect,
        padding: CGFloat = 24
    ) -> CGPoint? {
        let visibleTop = bounds.minY
        let visibleBottom = min(bounds.maxY, keyboardFrame.minY)
        let topLimit = visibleTop + padding
        let bottomLimit = visibleBottom - padding

        // Positive: the field extends below the keyboard. Negative maxDelta: it starts above the visible top.
        let minDelta = fieldRect.maxY - bottomLimit
        let maxDelta = fieldRect.minY - topLimit

        let delta: CGFloat
        if minDelta > 0 {
            delta = minDelta
        } else if maxDelta < 0 {
            delta = maxDelta
        } else {
            return nil
        }

        var offset = contentOffset
        offset.y += delta
        let maxOffsetY = max(0, contentSize.height - bounds.height)
        offset.y = min(max(0, offset.y), maxOffsetY)
        if abs(offset.y - contentOffset.y) < 0.5 {
            return nil
        }
        return offset
    }
}
