public struct JSVoidValue: Sendable, JSValueConvertible {
  public init() {}

  public init(jsValue: JSValue) throws {
    guard jsValue.isUndefined else { throw JSTypeMismatchError() }
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(undefinedIn: context)
  }
}
