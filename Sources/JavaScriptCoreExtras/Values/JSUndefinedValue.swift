import JavaScriptCore

/// A type that can be converted to and from a `JSValue` that represents `undefined`.
///
/// This type will always be converted to and from `undefined` in JavaScript.
public struct JSUndefinedValue: Sendable, JSValueConvertible {
  public init() {}

  public init(jsValue: JSValue) throws {
    guard jsValue.isUndefined else { throw JSTypeMismatchError() }
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(undefinedIn: context)
  }
}
