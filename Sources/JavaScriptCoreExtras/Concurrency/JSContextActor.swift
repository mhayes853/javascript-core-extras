import JavaScriptCore

public final actor JSContextActor {
  public let context: JSContext
  public let executor: JSVirtualMachineExecutor

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    self.executor.asUnownedSerialExecutor()
  }

  public static func currentForJSInvoke() -> JSContextActor? {
    guard
      let context = JSContext.current(),
      let executor = JSVirtualMachineExecutor.current()
    else { return nil }
    return JSContextActor(executor: executor) { _ in context }
  }

  public init?(
    executor: JSVirtualMachineExecutor,
    createContext: (JSVirtualMachine) -> JSContext = { JSContext(virtualMachine: $0) }
  ) {
    let context = executor.withVirtualMachineIfCurrentExecutor { vm in
      let context = createContext(vm)
      return context.virtualMachine == vm ? context : nil
    }
    guard case .some(let context?) = context else { return nil }
    self.context = context
    self.executor = executor
  }

  public func withIsolation<T, E: Error>(
    perform operation: (isolated JSContextActor) throws(E) -> sending T
  ) throws(E) -> sending T {
    try operation(self)
  }
}
