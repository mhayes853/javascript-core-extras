import JavaScriptCore

// MARK: - ConvertibleFromJSValue

/// A protocol that describes how to create a value from a `JSValue`.
public protocol ConvertibleFromJSValue {
  /// The error thrown if the `JSValue` cannot be converted.
  associatedtype FromJSValueFailure: Error
  
  /// Converts a `JSValue` to this value.
  ///
  /// - Parameter jsValue: The `JSValue` to convert.
  init(jsValue: JSValue) throws(FromJSValueFailure)
}

// MARK: - ConvertibleToJSValue

/// A protocol that describes how to convert a value into a `JSValue`.
public protocol ConvertibleToJSValue {
  /// The error thrown if this value cannot be converted.
  associatedtype ToJSValueFailure: Error
  
  /// Converts this value to a `JSValue`.
  ///
  /// - Parameter context: The `JSContext` to use for the conversion.
  /// - Returns: A `JSValue`.
  func jsValue(in context: JSContext) throws(ToJSValueFailure) -> JSValue
}

// MARK: - JSValueConvertible

/// A convenience typealias combining both ``ConvertibleFromJSValue`` and ``ConvertibleToJSValue``.
public typealias JSValueConvertible = ConvertibleFromJSValue & ConvertibleToJSValue
