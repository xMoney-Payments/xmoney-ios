import UIKit

/// Pay CTA painted with a shape layer. `UIButton`/`UIControl` ignore fill on iOS 26, and
/// `cornerRadius: 9999` + `clipsToBounds` can clip the entire control to an empty rect.
package final class PayCTAButton: UIView {
    package static let accessibilityID = "xmoney.pay"

    package let titleLabel = UILabel()
    private let fillLayer = CAShapeLayer()
    private let coinMarkContainer = UIView()
    private var coinMark: XCoinButtonMarkView?
    private var titleCenterX: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var requestedRadius: CGFloat = 12
    private var paintedFill: UIColor = .black

    package var onTap: (() -> Void)?
    package var isEnabled = true {
        didSet { isUserInteractionEnabled = isEnabled }
    }

    package var fillColor: UIColor? { paintedFill }

    package override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = Self.accessibilityID
        isUserInteractionEnabled = true
        // Do not use a huge layer.cornerRadius + clipsToBounds (iOS 26 clips the layer empty).
        clipsToBounds = false

        fillLayer.contentsScale = UIScreen.main.scale
        layer.insertSublayer(fillLayer, at: 0)

        titleLabel.isAccessibilityElement = false
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        coinMarkContainer.translatesAutoresizingMaskIntoConstraints = false
        coinMarkContainer.isHidden = true
        coinMarkContainer.isUserInteractionEnabled = false
        addSubview(coinMarkContainer)

        let centerX = titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        titleCenterX = centerX
        let height = heightAnchor.constraint(equalToConstant: 52)
        heightConstraint = height
        NSLayoutConstraint.activate([
            height,
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            centerX,
            coinMarkContainer.trailingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: -12),
            coinMarkContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            coinMarkContainer.widthAnchor.constraint(equalToConstant: 17),
            coinMarkContainer.heightAnchor.constraint(equalToConstant: 17 * 418 / 539),
        ])
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func layoutSubviews() {
        super.layoutSubviews()
        updateFillPath()
    }

    package func apply(theme: CheckoutTheme, title: String, processing: Bool, enabled: Bool) {
        paintedFill = theme.primaryButtonBackground
        requestedRadius = theme.primaryButtonBorderRadius
        heightConstraint?.constant = theme.payButtonHeight
        fillLayer.fillColor = paintedFill.cgColor
        fillLayer.strokeColor = theme.primaryButtonBorder.cgColor
        fillLayer.lineWidth = theme.primaryButtonBorderWidth
        updateFillPath()

        titleLabel.isHidden = false
        titleLabel.text = title
        titleLabel.textColor = theme.primaryButtonText
        titleLabel.font = theme.payFont(ofSize: 16, weight: .semibold)
        let tracking = -0.01 * 16 * theme.fontScale
        titleLabel.attributedText = NSAttributedString(
            string: title,
            attributes: [
                .font: theme.payFont(ofSize: 16, weight: .semibold),
                .foregroundColor: theme.primaryButtonText,
                .kern: tracking,
            ]
        )
        titleCenterX?.constant = processing ? 12 : 0
        accessibilityLabel = title

        isEnabled = enabled && !processing
        if processing {
            alpha = 0.9
            layer.shadowOpacity = 0
            showCoinMark(color: theme.primaryButtonText)
        } else if enabled {
            alpha = 1
            layer.shadowColor = UIColor(red: 124 / 255, green: 77 / 255, blue: 255 / 255, alpha: 1).cgColor
            layer.shadowOpacity = 0.30
            layer.shadowOffset = CGSize(width: 0, height: 8)
            layer.shadowRadius = 12
            layer.masksToBounds = false
            hideCoinMark()
        } else {
            alpha = 0.5
            layer.shadowOpacity = 0
            hideCoinMark()
        }
        setNeedsLayout()
    }

    private func updateFillPath() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let radius = min(max(requestedRadius, 0), bounds.height / 2)
        fillLayer.frame = bounds
        fillLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        fillLayer.fillColor = paintedFill.cgColor
        layer.shadowPath = fillLayer.path
    }

    @objc private func handleTap() {
        guard isEnabled else { return }
        onTap?()
    }

    private func showCoinMark(color: UIColor) {
        if coinMark == nil {
            let mark = XCoinButtonMarkView(color: color)
            mark.translatesAutoresizingMaskIntoConstraints = false
            coinMarkContainer.addSubview(mark)
            NSLayoutConstraint.activate([
                mark.centerXAnchor.constraint(equalTo: coinMarkContainer.centerXAnchor),
                mark.centerYAnchor.constraint(equalTo: coinMarkContainer.centerYAnchor),
            ])
            coinMark = mark
        } else {
            coinMark?.setTintColor(color)
        }
        coinMarkContainer.isHidden = false
        coinMark?.startAnimating()
    }

    private func hideCoinMark() {
        coinMarkContainer.isHidden = true
        coinMark?.stopAnimating()
    }
}
