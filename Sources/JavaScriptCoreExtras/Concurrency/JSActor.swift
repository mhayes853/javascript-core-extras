import JavaScriptCore

/// An actor that isolates a value to the same thread of a running ``JSVirtualMachineExecutor``.
///
/// You can use this actor to ensure thread safe access to `JSContext` or `JSValue` instances.
/// ```swift
/// @preconcurrency import JavaScriptCore
///
/// func setupAsyncWork(in executor: JSVirtualMachineExecutor) {
///   executor.withVirtualMachineIfCurrentExecutor { vm in
///     let context = JSContext(virtualMachine: vm)
///     let myAsyncWork: @convention(block) (JSValue) -> Void = { value in
///       let valueActor = JSActor(value, executor: executor)
///       Task {
///         try await asyncWork()
///         _ = await valueActor.withIsolation { @Sendable in
///           // Runs on the same thread as the underlying virtual machine.
///           $0.value.invokeMethod("onCompleted", withArguments: [])
///         }
///       }
///     }
///     context?.setObject(myAsyncWork, forPath: "myAsyncWork")
///   }
/// }
///
/// private func asyncWork() async throws {
///   // ...
/// }
/// ```
/// > Notice: You will need the preconcurrency import to avoid compiler errors related to
/// > sending non-Sendable `JSValue` or `JSContext` instances. This is safe as long as the
/// > `JSValue` or `JSContext` is tied to the same `JSVirtualMachine` as the executor.
public final actor JSActor<Value> {
  /// The isolated value.
  public var value: Value
  
  /// The executor of this actor.
  public let executor: JSVirtualMachineExecutor

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    self.executor.asUnownedSerialExecutor()
  }
  
  /// Returns a ``JSActor`` containing the current `JSContext` if the current context uses the
  /// same `JSVirtualMachine` as ``JSVirtualMachineExecutor/current()``.
  ///
  /// You can use this instead of `JSContext.current()` if you need to perform asynchronous work
  /// inside of a JS function invoke.
  ///```swift
  /// import JavaScriptCore
  ///
  /// let context = JSContext()
  /// let myAsyncWork: @convention(block) () -> Void = {
  ///   let contextActor = JSActor.currentContext()!
  ///   Task {
  ///     try await asyncWork()
  ///     _ = await contextActor.withIsolation { @Sendable in
  ///       // Runs on the same thread as the underlying virtual machine.
  ///       $0.globalObject.invokeMethod("globalCallback", withArguments: [])
  ///     }
  ///   }
  /// }
  /// context?.setObject(myAsyncWork, forPath: "myAsyncWork")
  /// ```
  ///
  /// - Returns: A ``JSActor`` that isolates current `JSContext.current()`, or nil if the current
  ///   context does not use the same `JSVirtualMachine` as ``JSVirtualMachineExecutor/current()``.
  public static func currentContext() -> JSActor<JSContext>? where Value == JSContext {
    guard
      let context = JSContext.current(),
      let executor = JSVirtualMachineExecutor.current()
    else { return nil }
    let virtualMachineMatch = executor.withVirtualMachineIfCurrentExecutor { vm in
      context.virtualMachine === vm
    }
    guard virtualMachineMatch ?? false else { return nil }
    return JSActor(context, executor: executor)
  }
  
  /// Creates a JS actor.
  ///
  /// - Parameters:
  ///   - value: The value to isolate.
  ///   - executor: The ``JSVirtualMachineExecutor`` to isolate the value on.
  public init(_ value: sending Value, executor: JSVirtualMachineExecutor) {
    self.value = value
    self.executor = executor
  }
  
  /// Performs an operation with isolated access to the value.
  ///
  /// - Parameter operation: The operation.
  /// - Returns: The result of the operation.
  public func withIsolation<T, E: Error>(
    perform operation: (isolated JSActor) throws(E) -> sending T
  ) throws(E) -> sending T {
    try operation(self)
  }
  
  /// Performs an operation with isolated access to the value and `JSVirtualMachine` of
  /// ``executor``.
  ///
  /// - Parameter operation: The operation.
  /// - Returns: The result of the operation.
  public func withIsolation<T, E: Error>(
    perform operation: (isolated JSActor, JSVirtualMachine) throws(E) -> sending T
  ) throws(E) -> sending T {
    // NB: Since this actor executes on the virtual machine thread, unwrapping is fine.
    try operation(self, JSVirtualMachine.threadLocal!)
  }
}
