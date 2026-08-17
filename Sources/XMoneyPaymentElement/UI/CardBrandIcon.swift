import UIKit
#if !COCOAPODS
import XMoneyCore
#endif

package enum CardBrandIconSize {
    case fieldTrailing
    case savedCardRow
    case useOtherCardPair
}

package final class CardBrandIcon: UIImageView {
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var mutedTint: UIColor = UIColor(red: 22 / 255, green: 20 / 255, blue: 26 / 255, alpha: 0.32)

    package init(size: CardBrandIconSize = .fieldTrailing) {
        super.init(frame: .zero)
        contentMode = .scaleAspectFit
        tintAdjustmentMode = .normal
        translatesAutoresizingMaskIntoConstraints = false
        widthConstraint = widthAnchor.constraint(equalToConstant: 24)
        heightConstraint = heightAnchor.constraint(equalToConstant: 24)
        widthConstraint?.isActive = true
        heightConstraint?.isActive = true
        setBrand(nil, size: size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMutedTint(_ color: UIColor) {
        mutedTint = color
        if image?.renderingMode == .alwaysTemplate {
            tintColor = color
        }
    }

    package func setBrand(_ brand: String?, size: CardBrandIconSize = .fieldTrailing) {
        let named: String
        let useTemplate: Bool
        let dimensions: (width: CGFloat, height: CGFloat)

        switch brand?.lowercased() {
        case "mastercard":
            named = "card-mastercard"
            useTemplate = false
            dimensions = Self.mastercardSize(size)
        case "visa":
            named = "card-visa"
            useTemplate = false
            dimensions = Self.visaSize(size)
        default:
            named = "card-generic"
            useTemplate = true
            dimensions = Self.genericSize(size)
        }

        widthConstraint?.constant = dimensions.width
        heightConstraint?.constant = dimensions.height

        let base = EmbeddedAssets.image(named: named, traitCollection: traitCollection)
        if useTemplate {
            image = base?.withRenderingMode(.alwaysTemplate)
            tintColor = mutedTint
        } else {
            image = base?.withRenderingMode(.alwaysOriginal)
            tintColor = nil
        }
    }

    private static func visaSize(_ size: CardBrandIconSize) -> (CGFloat, CGFloat) {
        switch size {
        case .fieldTrailing: return (34, 11)
        case .savedCardRow: return (31, 10)
        case .useOtherCardPair: return (28, 9)
        }
    }

    private static func mastercardSize(_ size: CardBrandIconSize) -> (CGFloat, CGFloat) {
        switch size {
        case .fieldTrailing: return (30, 19)
        case .savedCardRow: return (29, 18)
        case .useOtherCardPair: return (24, 15)
        }
    }

    private static func genericSize(_ size: CardBrandIconSize) -> (CGFloat, CGFloat) {
        switch size {
        case .fieldTrailing: return (24, 24)
        case .savedCardRow: return (20, 20)
        case .useOtherCardPair: return (18, 18)
        }
    }
}
