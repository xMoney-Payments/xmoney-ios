import Foundation

/// One-shot 3DS continuation. Poll-win and session completion cannot double-resume.
package final class ThreeDSResume<Value>: @unchecked Sendable {
    private var continuation: CheckedContinuation<Value, Never>?
    private let lock = NSLock()

    package init() {}

    package func arm(_ continuation: CheckedContinuation<Value, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    @discardableResult
    package func resume(_ value: Value) -> Bool {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return false }
        pending.resume(returning: value)
        return true
    }
}
