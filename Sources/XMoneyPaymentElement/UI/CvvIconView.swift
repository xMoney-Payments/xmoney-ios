import UIKit

/// Trailing CVV icon. Geometry matches `xmoney-checkout-sdks/src/assets/icons/cvv.js`.
final class CvvIconView: UIView {
    var iconColor: UIColor = .black {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: 20, height: 20) }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let scale = min(bounds.width / 24, bounds.height / 24)
        ctx.saveGState()
        ctx.translateBy(
            x: (bounds.width - 24 * scale) / 2,
            y: (bounds.height - 24 * scale) / 2
        )
        ctx.scaleBy(x: scale, y: scale)
        iconColor.setFill()

        Self.stripe.fill()

        let body = Self.body.copy() as! UIBezierPath
        body.append(Self.cardCutout)
        body.usesEvenOddFillRule = true
        body.fill()

        let badge = Self.badge.copy() as! UIBezierPath
        badge.append(Self.digits)
        badge.usesEvenOddFillRule = true
        badge.fill()

        ctx.restoreGState()
    }

    /// `M2 8A3 3 0 0 1 5 5h14a3 3 0 0 1 3 3v1H2V8z`
    private static let stripe: UIBezierPath = {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 2, y: 8))
        path.addArc(
            withCenter: CGPoint(x: 5, y: 8),
            radius: 3,
            startAngle: .pi,
            endAngle: -.pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: 19, y: 5))
        path.addArc(
            withCenter: CGPoint(x: 19, y: 8),
            radius: 3,
            startAngle: -.pi / 2,
            endAngle: 0,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: 22, y: 9))
        path.addLine(to: CGPoint(x: 2, y: 9))
        path.close()
        return path
    }()

    /// `M2 11h20v5a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3v-5z`
    private static let body: UIBezierPath = {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 2, y: 11))
        path.addLine(to: CGPoint(x: 22, y: 11))
        path.addLine(to: CGPoint(x: 22, y: 16))
        path.addArc(
            withCenter: CGPoint(x: 19, y: 16),
            radius: 3,
            startAngle: 0,
            endAngle: .pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: 5, y: 19))
        path.addArc(
            withCenter: CGPoint(x: 5, y: 16),
            radius: 3,
            startAngle: .pi / 2,
            endAngle: .pi,
            clockwise: true
        )
        path.close()
        return path
    }()

    /// Mask circle `cx="18.55" cy="16.7" r="5.5"`
    private static let cardCutout = UIBezierPath(ovalIn: CGRect(x: 13.05, y: 11.2, width: 11, height: 11))

    /// Badge `cx="18.55" cy="16.7" r="4.25"`
    private static let badge = UIBezierPath(ovalIn: CGRect(x: 14.3, y: 12.45, width: 8.5, height: 8.5))

    /// Arial Bold 4.9, letter-spacing -0.2, text-anchor middle at (18.55, 18.5).
    private static let digits = path(
        "M16.5907 18.5000L15.9184 18.5000L15.9184 15.9663Q15.5499 16.3108 15.0499 16.4759L15.0499 15.8658Q15.3131 15.7796 15.6217 15.5392Q15.9303 15.2987 16.0452 14.9781L16.5907 14.9781ZM19.6661 17.8755L19.6661 18.5000L17.3094 18.5000Q17.3477 18.1459 17.5391 17.8289Q17.7305 17.5119 18.2952 16.9879Q18.7498 16.5644 18.8527 16.4137Q18.9914 16.2055 18.9914 16.0021Q18.9914 15.7772 18.8706 15.6564Q18.7498 15.5356 18.5368 15.5356Q18.3263 15.5356 18.2019 15.6624Q18.0775 15.7892 18.0583 16.0835L17.3884 16.0165Q17.4482 15.4614 17.7640 15.2198Q18.0799 14.9781 18.5536 14.9781Q19.0728 14.9781 19.3695 15.2581Q19.6661 15.5380 19.6661 15.9543Q19.6661 16.1912 19.5812 16.4053Q19.4963 16.6194 19.3120 16.8539Q19.1900 17.0094 18.8718 17.3013Q18.5536 17.5932 18.4687 17.6889Q18.3837 17.7846 18.3311 17.8755ZM19.8968 17.5693L20.5476 17.4903Q20.5787 17.7392 20.7151 17.8708Q20.8514 18.0023 21.0452 18.0023Q21.2534 18.0023 21.3958 17.8444Q21.5381 17.6865 21.5381 17.4186Q21.5381 17.1649 21.4017 17.0166Q21.2654 16.8683 21.0692 16.8683Q20.9400 16.8683 20.7605 16.9185L20.8347 16.3706Q21.1074 16.3778 21.2510 16.2522Q21.3946 16.1266 21.3946 15.9184Q21.3946 15.7414 21.2893 15.6361Q21.1840 15.5308 21.0094 15.5308Q20.8371 15.5308 20.7151 15.6504Q20.5930 15.7701 20.5667 15.9998L19.9470 15.8945Q20.0116 15.5763 20.1420 15.3861Q20.2724 15.1958 20.5057 15.0870Q20.7390 14.9781 21.0285 14.9781Q21.5238 14.9781 21.8228 15.2939Q22.0693 15.5523 22.0693 15.8777Q22.0693 16.3395 21.5644 16.6146Q21.8659 16.6792 22.0465 16.9042Q22.2272 17.1291 22.2272 17.4473Q22.2272 17.9090 21.8898 18.2344Q21.5525 18.5598 21.0500 18.5598Q20.5739 18.5598 20.2605 18.2859Q19.9470 18.0119 19.8968 17.5693Z"
    )

    private static func path(_ d: String) -> UIBezierPath {
        let path = UIBezierPath()
        let scanner = Scanner(string: d)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ,")
        var command: Character = "M"
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        func number() -> CGFloat? {
            var value = 0.0
            guard scanner.scanDouble(&value) else { return nil }
            return CGFloat(value)
        }

        while !scanner.isAtEnd {
            let before = scanner.currentIndex
            if let letter = scanner.scanCharacters(from: .letters), let next = letter.first {
                command = next
                if command == "Z" || command == "z" {
                    path.close()
                    current = subpathStart
                    continue
                }
            } else {
                scanner.currentIndex = before
            }

            switch command {
            case "M":
                guard let x = number(), let y = number() else { return path }
                current = CGPoint(x: x, y: y)
                path.move(to: current)
                subpathStart = current
                command = "L"
            case "L":
                guard let x = number(), let y = number() else { return path }
                current = CGPoint(x: x, y: y)
                path.addLine(to: current)
            case "Q":
                guard let cx = number(), let cy = number(), let x = number(), let y = number() else { return path }
                current = CGPoint(x: x, y: y)
                path.addQuadCurve(to: current, controlPoint: CGPoint(x: cx, y: cy))
            default:
                return path
            }
        }
        return path
    }
}
