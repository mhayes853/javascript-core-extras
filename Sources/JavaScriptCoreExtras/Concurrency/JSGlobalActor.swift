import JavaScriptCore

// MARK: - JSGlobalActor

/// A global actor for background JavaScript execution.
///
/// You can use this global actor as a simple way to execute JavaScript on a dedicated background
/// thread of your application.
/// ```swift
/// @JSGlobalActor
/// func runJS() {
///   let context = JSContext(virtualMachine: JSGlobalActor.virtualMachine)
///
///   // ...
/// }
///
/// func foo() async {
///   // @JSGlobalActor behaves like @MainActor, so you'll have to await
///   // access.
///   await runJS()
/// }
/// ```
///
/// Just like `@MainActor`, you can also annotate entire classes, properties, or functions with
/// `@JSGlobalActor`.
/// ```swift
/// @JSGlobalActor
/// class JavaScriptRuntime {
///   var context = JSContext(virtualMachine: JSGlobalActor.virtualMachine)
///
///   // ...
/// }
///
/// @JSGlobalActor
/// var global: Int {
///   // ...
/// }
/// ```
///
/// > Note: This global actor only uses a single dedicated background thread to manage execution of
/// > JavaScript in your application. This is simple, but it prevents you from executing JavaScript
/// > in concurrently on multiple threads in the background. If you want to run JavaScript on
/// > multiple threads in the background in a manner that's compatible with Swift concurrency, use
/// > ``JSVirtualMachinePool``, ``JSVirtualMachineExecutor``, and ``JSActor`` directly.
@globalActor
public final actor JSGlobalActor {
  public static let shared = JSGlobalActor()

  /// The `JSVirtualMachine` used by the JavaScript global actor.
  @JSGlobalActor
  public static var virtualMachine: JSVirtualMachine {
    // NB: Since this actor executes on the virtual machine thread, unwrapping is fine.
    JSVirtualMachine.threadLocal!
  }
  
  /// The ``JSVirtualMachineExecutor`` used by the JavaScript global actor.
  @JSGlobalActor
  public static var executor: JSVirtualMachineExecutor {
    Self.shared.executor
  }
  
  /// Execute the given body closure on the JavaScript global actor.
  @JSGlobalActor
  public static func run<T, E: Error>(
    operation: @JSGlobalActor () throws(E) -> sending T
  ) throws(E) -> sending T {
    try operation()
  }

  private let executor: JSVirtualMachineExecutor

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    self.executor.asUnownedSerialExecutor()
  }

  private init() {
    self.executor = JSVirtualMachineExecutor()
    self.executor.blockUntilStartsRunning()
  }
}

// MARK: - Helpers

extension JSVirtualMachineExecutor {
  fileprivate func blockUntilStartsRunning() {
    let condition = NSCondition()
    condition.lock()

    Thread.detachNewThread { [weak self] in
      condition.lock()
      condition.signal()
      condition.unlock()
      self?.runBlocking()
    }

    condition.wait()
    condition.unlock()
  }
}
