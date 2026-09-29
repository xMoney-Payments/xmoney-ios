import Foundation
#if canImport(XMoneyCore)
import XMoneyCore
#endif

/// Merchant-facing events from a mounted Payment Element.
///
/// ``processing`` is an in-flight charge only. ``ready`` is emitted once the card
/// form has been laid out and, when Apple Pay is offered, the Apple Pay button
/// has drawn. ``PaymentElement/updateOrder(intent:)`` emits ``ready`` again after
/// the updated form has laid out. ``updateOrder`` locks Pay via
/// ``EmbeddedPayment/isInteractionEnabled`` and does not emit ``processing``.
public enum EmbeddedEvent {
    case ready
    case processing(Bool)
}
