public struct JSError: Error {
  public let valueActor: JSActor<JSValue>?

  public init(valueActor: JSActor<JSValue>? = nil) {
    self.valueActor = valueActor
  }
}
