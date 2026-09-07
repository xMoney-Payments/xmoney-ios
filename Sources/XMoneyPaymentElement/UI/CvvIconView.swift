import UIKit

/// Trailing CVV icon: card body asset with CVV badge overlay (matches `cvv.js`).
final class CvvIconView: UIView {
    var iconColor: UIColor = .black {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        translatesAutoresizingMaskIntoConstraints = false
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: 24, height: 24) }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(),
              let card = Self.cardImage else { return }

        ctx.saveGState()
        let scale = min(rect.width, rect.height) / 24
        ctx.scaleBy(x: scale, y: scale)

        card.withTintColor(iconColor, renderingMode: .alwaysOriginal)
            .draw(in: CGRect(x: 0, y: 0, width: 24, height: 24))

        ctx.setBlendMode(.destinationOut)
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fillEllipse(in: Self.cardCutoutRect)

        ctx.setBlendMode(.normal)
        ctx.setFillColor(iconColor.cgColor)
        ctx.addPath(Self.badge.cgPath)
        ctx.addPath(Self.digits.cgPath)
        ctx.fillPath(using: .evenOdd)

        ctx.restoreGState()
    }

    private static let cardImage = EmbeddedAssets
        .image(named: "card-cvv-base")?
        .withRenderingMode(.alwaysTemplate)

    /// Mask `#xmoney-cvv-card`: circle r=5.5 at (18.55, 16.7).
    private static let cardCutoutRect = CGRect(x: 13.05, y: 11.2, width: 11, height: 11)

    /// Badge circle r=4.25 at (18.55, 16.7).
    private static let badge = UIBezierPath(ovalIn: CGRect(x: 14.3, y: 12.45, width: 8.5, height: 8.5))

    /// Mask `#xmoney-cvv-badge`: converted Arial Bold “123” outlines.
    private static let digits = path(
        "M16.5907 18.5000L15.9184 18.5000L15.9184 15.9663Q15.5499 16.3108 15.0499 16.4759L15.0499 15.8658Q15.3131 15.7796 15.6217 15.5392Q15.9303 15.2987 16.0452 14.9781L16.5907 14.9781ZM19.6661 17.8755L19.6661 18.5000L17.3094 18.5000Q17.3477 18.1459 17.5391 17.8289Q17.7305 17.5119 18.2952 16.9879Q18.7498 16.5644 18.8527 16.4137Q18.9914 16.2055 18.9914 16.0021Q18.9914 15.7772 18.8706 15.6564Q18.7498 15.5356 18.5368 15.5356Q18.3263 15.5356 18.2019 15.6624Q18.0775 15.7892 18.0583 16.0835L17.3884 16.0165Q17.4482 15.4614 17.7640 15.2198Q18.0799 14.9781 18.5536 14.9781Q19.0728 14.9781 19.3695 15.2581Q19.6661 15.5380 19.6661 15.9543Q19.6661 16.1912 19.5812 16.4053Q19.4963 16.6194 19.3120 16.8539Q19.1900 17.0094 18.8718 17.3013Q18.5536 17.5932 18.4687 17.6889Q18.3837 17.7846 18.3311 17.8755ZM19.8968 17.5693L20.5476 17.4903Q20.5787 17.7392 20.7151 17.8708Q20.8514 18.0023 21.0452 18.0023Q21.2534 18.0023 21.3958 17.8444Q21.5381 17.6865 21.5381 17.4186Q21.5381 17.1649 21.4017 17.0166Q21.2654 16.8683 21.0692 16.8683Q20.9400 16.8683 20.7605 16.9185L20.8347 16.3706Q21.1074 16.3778 21.2510 16.2522Q21.3946 16.1266 21.3946 15.9184Q21.3946 15.7414 21.2893 15.6361Q21.1840 15.5308 21.0094 15.5308Q20.8371 15.5308 20.7151 15.6504Q20.5930 15.7701 20.5667 15.9998L19.9470 15.8945Q20.0116 15.5763 20.1420 15.3861Q20.2724 15.1958 20.5057 15.0870Q20.7390 14.9781 21.0285 14.9781Q21.5238 14.9781 21.8228 15.2939Q22.0693 15.5523 22.0693 15.8777Q22.0693 16.3395 21.5644 16.6146Q21.8659 16.6792 22.0465 16.9042Q22.2272 17.1291 22.2272 17.4473Q22.2272 17.9090 21.8898 18.2344Q21.5525 18.5598 21.0500 18.5598Q20.5739 18.5598 20.2605 18.2859Q19.9470 18.0119 19.8968 17.5693Z"
    )

    private static func path(_ d: String) -> UIBezierPath {
        let path = UIBezierPath()
        let tokens = tokenizePath(d)
        var index = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        func readNumber() -> CGFloat? {
            guard index < tokens.count, let value = Double(tokens[index]) else { return nil }
            index += 1
            return CGFloat(value)
        }

        while index < tokens.count {
            let token = tokens[index]
            if token.count == 1, let letter = token.first, letter.isLetter {
                command = letter
                index += 1
                if command == "Z" || command == "z" {
                    path.close()
                    current = subpathStart
                }
                continue
            }

            switch command {
            case "M":
                guard let x = readNumber(), let y = readNumber() else { return path }
                current = CGPoint(x: x, y: y)
                path.move(to: current)
                subpathStart = current
                command = "L"
            case "L":
                guard let x = readNumber(), let y = readNumber() else { return path }
                current = CGPoint(x: x, y: y)
                path.addLine(to: current)
            case "Q":
                guard let cx = readNumber(), let cy = readNumber(), let x = readNumber(), let y = readNumber() else {
                    return path
                }
                current = CGPoint(x: x, y: y)
                path.addQuadCurve(to: current, controlPoint: CGPoint(x: cx, y: cy))
            default:
                return path
            }
        }

        return path
    }

    private static func tokenizePath(_ d: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        func flush() {
            guard !current.isEmpty else { return }
            tokens.append(current)
            current = ""
        }

        for character in d {
            if character.isLetter {
                flush()
                tokens.append(String(character))
            } else if character == " " || character == "," {
                flush()
            } else if character == "-" && !current.isEmpty && !current.hasSuffix("e") && !current.hasSuffix("E") {
                flush()
                current.append(character)
            } else {
                current.append(character)
            }
        }

        flush()
        return tokens
    }
}
