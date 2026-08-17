import UIKit

final class LockIconView: UIView {
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

    override var intrinsicContentSize: CGSize { CGSize(width: 19, height: 20) }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let scaleX = bounds.width / 24
        let scaleY = bounds.height / 24
        ctx.saveGState()
        ctx.scaleBy(x: scaleX, y: scaleY)
        iconColor.setFill()

        let shackle = UIBezierPath()
        shackle.move(to: CGPoint(x: 7, y: 9))
        shackle.addLine(to: CGPoint(x: 7, y: 7.5))
        shackle.addArc(
            withCenter: CGPoint(x: 12, y: 7.5),
            radius: 5,
            startAngle: .pi,
            endAngle: 0,
            clockwise: true
        )
        shackle.addLine(to: CGPoint(x: 17, y: 9))
        shackle.addLine(to: CGPoint(x: 14.8, y: 9))
        shackle.addLine(to: CGPoint(x: 14.8, y: 7.5))
        shackle.addArc(
            withCenter: CGPoint(x: 12, y: 7.5),
            radius: 2.8,
            startAngle: 0,
            endAngle: .pi,
            clockwise: false
        )
        shackle.addLine(to: CGPoint(x: 9.2, y: 9))
        shackle.close()
        shackle.fill()

        let body = UIBezierPath(
            roundedRect: CGRect(x: 4.5, y: 9, width: 15, height: 11),
            cornerRadius: 2.5
        )
        let keyhole = UIBezierPath(
            arcCenter: CGPoint(x: 12, y: 14.35),
            radius: 1.15,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        let stem = UIBezierPath(
            roundedRect: CGRect(x: 11.4, y: 14.7, width: 1.2, height: 1.75),
            cornerRadius: 0.3
        )
        body.append(keyhole)
        body.append(stem)
        body.usesEvenOddFillRule = true
        body.fill()

        ctx.restoreGState()
    }
}
