import Foundation
#if canImport(XMoneyCore)
import XMoneyCore
#endif

public enum EmbeddedEvent {
    case ready
    case processing(Bool)
}
