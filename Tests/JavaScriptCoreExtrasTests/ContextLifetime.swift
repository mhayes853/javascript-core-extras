import Foundation
import JavaScriptCoreExtras

// MARK: - ContextLifetime

/// The result of running a script with ``withContextLifetime(timeout:script:install:)``.
struct ContextLifetime: Sendable {
  /// Whether the Promise returned by the script settled before the timeout.
  var didSettle: Bool

  /// Whether the `JSContext` and its `JSVirtualMachine` were deallocated after being released.
  var isFreed: Bool
}

/// Runs `script` in a fresh `JSContext` on a dedicated thread, releases the context, and reports
/// whether it and its `JSVirtualMachine` were then deallocated.
///
/// The thread's run loop is spun while waiting for the Promise that `script` evaluates to, if
/// any, to settle, so that work resumed through the run loop fallback (ie. when no
/// ``JSVirtualMachineExecutor`` is in use) can complete. Anything native code still retains
/// after that, such as a `JSValue`, keeps the context alive and makes `isFreed` false.
///
/// - Parameters:
///   - timeout: How long to wait for the Promise to settle, and then for the context to be freed.
///   - script: The script to evaluate.
///   - install: Installs whatever the script needs into the context.
/// - Returns: A ``ContextLifetime``.
func withContextLifetime(
  timeout: TimeInterval = 2,
  script: String,
  install: @escaping @Sendable (JSContext) throws -> Void
) async throws -> ContextLifetime {
  try await withCheckedThrowingContinuation { continuation in
    Thread {
      weak var weakContext: JSContext?
      weak var weakVirtualMachine: JSVirtualMachine?
      let didSettle = SettledFlag()
      do {
        try autoreleasepool {
          let virtualMachine = JSVirtualMachine()!
          let context = JSContext(virtualMachine: virtualMachine)!
          weakContext = context
          weakVirtualMachine = virtualMachine
          try install(context)
          let value = context.evaluateScript(script)!
          if let promise = value.toPromise() {
            promise.then { _ in
              didSettle.value = true
              return nil
            } onRejected: { _ in
              didSettle.value = true
              return nil
            }
            spinRunLoop(timeout: timeout) { didSettle.value }
          }
        }
      } catch {
        continuation.resume(throwing: error)
        return
      }
      spinRunLoop(timeout: timeout) { weakContext == nil && weakVirtualMachine == nil }
      continuation.resume(
        returning: ContextLifetime(
          didSettle: didSettle.value,
          isFreed: weakContext == nil && weakVirtualMachine == nil
        )
      )
    }
    .start()
  }
}

private final class SettledFlag: @unchecked Sendable {
  var value = false
}

private func spinRunLoop(timeout: TimeInterval, until condition: () -> Bool) {
  let deadline = Date(timeIntervalSinceNow: timeout)
  while !condition() && Date() < deadline {
    _ = autoreleasepool { CFRunLoopRunInMode(.defaultMode, 0.01, true) }
  }
}
