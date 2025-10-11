import JavaScriptCore

public protocol ConvertibleFromJSValue {
  associatedtype FromJSValueFailure: Error

  init(jsValue: JSValue) throws(FromJSValueFailure)
}

public protocol ConvertibleToJSValue {
  associatedtype ToJSValueFailure: Error

  func jsValue(in context: JSContext) throws(ToJSValueFailure) -> JSValue
}

public typealias JSValueConvertible = ConvertibleFromJSValue & ConvertibleToJSValue
