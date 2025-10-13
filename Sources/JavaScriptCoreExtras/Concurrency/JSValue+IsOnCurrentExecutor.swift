import JavaScriptCore

extension JSValue {
  public var isOnCurrentExecutor: Bool {
    guard let executor = JSVirtualMachineExecutor.current() else {
      return false
    }
    return executor.withVirtualMachineIfCurrentExecutor {
      self.context.virtualMachine === $0
    } ?? false
  }
}

extension JSContext {
  public var isOnCurrentExecutor: Bool {
    self.globalObject.isOnCurrentExecutor
  }
}
