@preconcurrency import JavaScriptCore

public struct JSError: Error {
  public let valueActor: JSActor<JSValue>?
  public let message: String?

  public init(valueActor: JSActor<JSValue>? = nil, message: String? = nil) {
    self.valueActor = valueActor
    self.message = message
  }

  public init(onCurrentExecutor jsValue: JSValue) {
    let message = try? jsValue.value(forKey: "message", as: String.self)
    guard let executor = JSVirtualMachineExecutor.current() else {
      self.init(message: message)
      return
    }
    // NB: This is safe because we're on the specified executor thread, and the actor will
    // isolate the exception to that thread.
    self.init(
      valueActor: jsValue.isOnCurrentExecutor ? JSActor(jsValue, executor: executor) : nil,
      message: message
    )
  }
}
