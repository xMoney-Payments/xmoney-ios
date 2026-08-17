import UIKit

private let xCoinAspect: CGFloat = 418.0 / 539.0

package final class XCoinFlipLoaderView: UIView {
    private let markContainer = UIView()
    private let markView = UIImageView()

    package init(
        color: UIColor = CheckoutTheme.brandPrimary,
        size: CGFloat = 72
    ) {
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityLabel = "Loading"

        let markHeight = size * xCoinAspect

        markContainer.translatesAutoresizingMaskIntoConstraints = false
        // Perspective on the container so child rotation.y animations are not overwritten.
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / (12 * UIScreen.main.scale * 8)
        markContainer.layer.sublayerTransform = perspective

        markView.image = EmbeddedAssets.image(named: "xmoney-xmark")?.withRenderingMode(.alwaysTemplate)
        markView.tintColor = color
        markView.contentMode = .scaleAspectFit
        markView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(markContainer)
        markContainer.addSubview(markView)

        NSLayoutConstraint.activate([
            markContainer.topAnchor.constraint(equalTo: topAnchor),
            markContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            markContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            markContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            markContainer.widthAnchor.constraint(equalToConstant: size),
            markContainer.heightAnchor.constraint(equalToConstant: markHeight),

            markView.topAnchor.constraint(equalTo: markContainer.topAnchor),
            markView.leadingAnchor.constraint(equalTo: markContainer.leadingAnchor),
            markView.trailingAnchor.constraint(equalTo: markContainer.trailingAnchor),
            markView.bottomAnchor.constraint(equalTo: markContainer.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    package func startAnimating() {
        stopAnimating()

        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.y")
        rotation.duration = 2.6
        rotation.values = [0, CGFloat.pi, CGFloat.pi, CGFloat.pi * 2, CGFloat.pi * 2]
        rotation.keyTimes = [0, 988.0 / 2600.0, 1300.0 / 2600.0, 2288.0 / 2600.0, 1] as [NSNumber]
        rotation.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.55, 0.02, 0.35, 1),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(controlPoints: 0.55, 0.02, 0.35, 1),
            CAMediaTimingFunction(name: .linear),
        ]
        rotation.repeatCount = .infinity
        markView.layer.add(rotation, forKey: "xCoinFlip")
    }

    package func stopAnimating() {
        markView.layer.removeAllAnimations()
    }
}

package final class XCoinButtonMarkView: UIView {
    private let markContainer = UIView()
    private let markView = UIImageView()

    package init(color: UIColor, size: CGFloat = 17) {
        super.init(frame: .zero)
        let markHeight = size * xCoinAspect

        markContainer.translatesAutoresizingMaskIntoConstraints = false
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / (8 * UIScreen.main.scale * 8)
        markContainer.layer.sublayerTransform = perspective

        markView.image = EmbeddedAssets.image(named: "xmoney-xmark")?.withRenderingMode(.alwaysTemplate)
        markView.tintColor = color
        markView.contentMode = .scaleAspectFit
        markView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(markContainer)
        markContainer.addSubview(markView)
        NSLayoutConstraint.activate([
            markContainer.topAnchor.constraint(equalTo: topAnchor),
            markContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            markContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            markContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: markHeight),

            markView.topAnchor.constraint(equalTo: markContainer.topAnchor),
            markView.leadingAnchor.constraint(equalTo: markContainer.leadingAnchor),
            markView.trailingAnchor.constraint(equalTo: markContainer.trailingAnchor),
            markView.bottomAnchor.constraint(equalTo: markContainer.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    package func startAnimating() {
        stopAnimating()
        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.y")
        rotation.duration = 1.5
        rotation.values = [0, CGFloat.pi * 2, CGFloat.pi * 2]
        rotation.keyTimes = [0, 825.0 / 1500.0, 1] as [NSNumber]
        rotation.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.5, 0.05, 0.35, 1),
            CAMediaTimingFunction(name: .linear),
        ]
        rotation.repeatCount = .infinity
        markView.layer.add(rotation, forKey: "xBtnCoin")
    }

    package func stopAnimating() {
        markView.layer.removeAllAnimations()
    }

    package func setTintColor(_ color: UIColor) {
        markView.tintColor = color
    }
}
