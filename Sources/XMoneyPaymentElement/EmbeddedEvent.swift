import Foundation
#if canImport(XMoneyCore)
import XMoneyCore
#endif

/// Merchant-facing events from a mounted Payment Element.
///
/// ``processing`` is an in-flight charge only. ``ready`` is emitted once the card
/// form has been laid out and, when Apple Pay is offered, the Apple Pay button
/// has drawn. A later ``PaymentElement/updateOrder(intent:)`` does not emit it
/// again. ``updateOrder`` locks Pay via
/// ``EmbeddedPayment/isInteractionEnabled`` and does not emit ``processing``.
public enum EmbeddedEvent {
    case ready
    case processing(Bool)
}
