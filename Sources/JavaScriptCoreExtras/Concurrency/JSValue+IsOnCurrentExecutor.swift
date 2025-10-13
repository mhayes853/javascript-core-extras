import JavaScriptCore

extension JSValue {
  /// Returns true if this value has the same virtual machine as
  /// ``JSVirtualMachineExecutor/current()``.
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
  /// Returns true if this context has the same virtual machine as
  /// ``JSVirtualMachineExecutor/current()``.
  public var isOnCurrentExecutor: Bool {
    self.globalObject.isOnCurrentExecutor
  }
}
