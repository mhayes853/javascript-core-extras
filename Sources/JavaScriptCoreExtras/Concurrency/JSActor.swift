import JavaScriptCore

public final actor JSActor<Value> {
  public var value: Value
  public let executor: JSVirtualMachineExecutor

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    self.executor.asUnownedSerialExecutor()
  }

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

  public init(_ value: sending Value, executor: JSVirtualMachineExecutor) {
    self.value = value
    self.executor = executor
  }

  public func withIsolation<T, E: Error>(
    perform operation: (isolated JSActor) throws(E) -> sending T
  ) throws(E) -> sending T {
    try operation(self)
  }

  public func withIsolation<T, E: Error>(
    perform operation: (isolated JSActor, JSVirtualMachine) throws(E) -> sending T
  ) throws(E) -> sending T {
    // NB: Since this actor executes on the virtual machine thread, unwrapping is fine.
    try operation(self, JSVirtualMachine.threadLocal!)
  }
}
