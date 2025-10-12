import CoreGraphics
import JavaScriptCore

// MARK: - CGRect

extension CGRect: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isRect else { throw JSTypeMismatchError() }
    self = jsValue.toRect()
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(rect: self, in: context)
  }
}

extension JSValue {
  public var isRect: Bool {
    self.objectForKeyedSubscript("x").isNumber && self.objectForKeyedSubscript("y").isNumber
      && self.objectForKeyedSubscript("width").isNumber
      && self.objectForKeyedSubscript("height").isNumber
  }
}

// MARK: - CGSize

extension CGSize: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isSize else { throw JSTypeMismatchError() }
    self = jsValue.toSize()
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(size: self, in: context)
  }
}

extension JSValue {
  public var isSize: Bool {
    self.objectForKeyedSubscript("width").isNumber
      && self.objectForKeyedSubscript("height").isNumber
  }
}
