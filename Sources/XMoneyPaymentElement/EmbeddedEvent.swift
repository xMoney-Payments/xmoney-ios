import Foundation
#if !COCOAPODS
import XMoneyCore
#endif

public enum EmbeddedEvent {
    case ready
    case processing(Bool)
}
