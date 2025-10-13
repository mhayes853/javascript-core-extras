@preconcurrency import JavaScriptCore

/// An error thrown by JavaScript code.
public struct JSError: Error {
  /// A ``JSActor`` isolating the error value.
  public let valueActor: JSActor<JSValue>?
  
  /// The error message.
  public let message: String?
  
  /// Creates an error.
  ///
  /// - Parameters:
  ///   - valueActor: A ``JSActor`` isolating the error value.
  ///   - message: The error message.
  public init(valueActor: JSActor<JSValue>? = nil, message: String? = nil) {
    self.valueActor = valueActor
    self.message = message
  }
  
  /// Creates an error assuming the specified `JSValue` is compatible with
  /// ``JSVirtualMachineExecutor/current()``.
  ///
  /// If no current executor is present, or if the value is not compatible with the current
  /// executor, then ``valueActor`` will be nil.
  ///
  /// - Parameter jsValue: The error value.
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
