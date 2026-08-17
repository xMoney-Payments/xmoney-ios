import Foundation

/// One-shot 3DS continuation. Poll-win + WebView completion cannot double-resume.
package final class ThreeDSResume: @unchecked Sendable {
    private var continuation: CheckedContinuation<Bool, Never>?
    private let lock = NSLock()

    package init() {}

    package func arm(_ continuation: CheckedContinuation<Bool, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    @discardableResult
    package func resume(_ success: Bool) -> Bool {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return false }
        pending.resume(returning: success)
        return true
    }
}
