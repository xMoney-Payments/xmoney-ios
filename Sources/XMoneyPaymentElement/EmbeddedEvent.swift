import Foundation
#if canImport(XMoneyCore)
import XMoneyCore
#endif

/// Merchant-facing events from a mounted Payment Element.
///
/// ``processing`` is an in-flight charge only. ``EmbeddedPayment/updateOrder(intent:)``
/// locks Pay via ``EmbeddedPayment/isInteractionEnabled`` and emits ``ready`` when
/// bind finishes — it does not emit ``processing``.
public enum EmbeddedEvent {
    case ready
    case processing(Bool)
}
