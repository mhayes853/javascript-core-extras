import Foundation

// MARK: - RunLoopFallbackContext

/// Captures the calling thread's run loop so that work can later be dispatched back onto it.
///
/// This is a fallback for resuming Promise continuations when no ``JSVirtualMachineExecutor`` is
/// currently running. Host applications that drive their `JSContext` directly from a single
/// thread's own run loop (eg. the main thread) rather than adopting `JSVirtualMachineExecutor`
/// still need a safe way to hop asynchronous work back onto that thread.
package final class RunLoopFallbackContext: @unchecked Sendable {
  private let runLoop: CFRunLoop
  private let thread: Thread

  /// Captures the current thread and its run loop.
  package init() {
    self.runLoop = CFRunLoopGetCurrent()
    self.thread = .current
  }

  /// Performs `work` on the captured thread.
  ///
  /// If already running on the captured thread, `work` is invoked synchronously. Otherwise it is
  /// scheduled onto the captured thread's run loop.
  ///
  /// - Parameter work: The work to perform.
  package func perform(_ work: @escaping @Sendable () -> Void) {
    if Thread.current === self.thread {
      work()
    } else {
      CFRunLoopPerformBlock(self.runLoop, CFRunLoopMode.defaultMode.rawValue, work)
      CFRunLoopWakeUp(self.runLoop)
    }
  }
}
