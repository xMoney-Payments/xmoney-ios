import Foundation
#if canImport(XMoneyCore)
import XMoneyCore
#endif

/// Merchant-facing events from a mounted Payment Element.
///
/// ``processing`` is an in-flight charge only. ``ready`` is emitted once the card
/// form has been laid out and, when Apple Pay is offered, the Apple Pay button
/// has drawn. It is never emitted on the failure state; a later successful
/// retry emits it then. A later ``PaymentElement/updateOrder(intent:)`` does not
/// emit it again. ``updateOrder`` locks Pay via
/// ``EmbeddedPayment/isInteractionEnabled`` and does not emit ``processing``.
public enum EmbeddedEvent {
    case ready
    case processing(Bool)
    /// Binding a new order failed after an order was already bound. Pay stays
    /// locked on the stale order until a later `updateOrder` succeeds.
    case updateFailed(PaymentError)
}
