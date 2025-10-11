import Foundation

// MARK: - Date

extension Date: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isDate else { throw JSTypeMismatchError() }
    self = jsValue.toDate()
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(object: self, in: context)
  }
}

// MARK: - UUID

extension UUID: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isString else { throw JSTypeMismatchError() }
    guard let uuid = Self(uuidString: jsValue.toString()) else { throw InvalidUUIDError() }
    self = uuid
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(object: self.uuidString, in: context)
  }

  private struct InvalidUUIDError: Error {}
}
