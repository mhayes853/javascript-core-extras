import JavaScriptCore

public final actor JSContextActor {
  private var context: JSContext?
  public let executor: JSVirtualMachineExecutor

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    self.executor.asUnownedSerialExecutor()
  }

  public init(executor: JSVirtualMachineExecutor) {
    self.executor = executor
  }

  public func withContext<T, E: Error>(
    perform operation: (isolated JSContextActor, JSContext) throws(E) -> sending T
  ) throws(E) -> sending T {
    self.context = self.context ?? self.newContext()
    return try operation(self, self.context!)
  }

  private func newContext() -> JSContext {
    guard let vm = JSVirtualMachine.threadLocal else { executorNotRunning() }
    return JSContext(virtualMachine: vm)
  }
}
