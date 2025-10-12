import JavaScriptCore

// MARK: - Signed Integers

extension Int: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().intValue
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(int32: Int32(self), in: context)
  }
}

extension Int8: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().int8Value
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(int32: Int32(self), in: context)
  }
}

extension Int16: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().int16Value
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(int32: Int32(self), in: context)
  }
}

extension Int32: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().int32Value
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(int32: self, in: context)
  }
}

// MARK: - Unsigned Integers

extension UInt: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().uintValue
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(uInt32: UInt32(self), in: context)
  }
}

extension UInt8: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().uint8Value
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(uInt32: UInt32(self), in: context)
  }
}

extension UInt16: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().uint16Value
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(uInt32: UInt32(self), in: context)
  }
}

extension UInt32: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().uint32Value
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(uInt32: self, in: context)
  }
}

// MARK: - Big Integers

@available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
extension Int64: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isBigInt else { throw JSTypeMismatchError() }
    self = jsValue.toInt64()
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(newBigIntFrom: self, in: context) ?? JSValue(undefinedIn: context)
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
extension UInt64: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isBigInt else { throw JSTypeMismatchError() }
    self = jsValue.toUInt64()
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(newBigIntFrom: self, in: context) ?? JSValue(undefinedIn: context)
  }
}

// MARK: - String

extension String: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isString else { throw JSTypeMismatchError() }
    self = jsValue.toString()
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(object: self, in: context)
  }
}

// MARK: - Bool

extension Bool: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isBoolean else { throw JSTypeMismatchError() }
    self = jsValue.toBool()
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(bool: self, in: context)
  }
}

// MARK: - Floating Point Values

extension Double: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toDouble()
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(double: self, in: context)
  }
}

extension Float: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    guard jsValue.isNumber else { throw JSTypeMismatchError() }
    self = jsValue.toNumber().floatValue
  }

  public func jsValue(in context: JSContext) -> JSValue {
    JSValue(double: Double(self), in: context)
  }
}

// MARK: - Never

extension Never: JSValueConvertible {
  public init(jsValue: JSValue) throws {
    throw NeverConvertibleError()
  }

  public func jsValue(in context: JSContext) throws -> JSValue {
    throw NeverConvertibleError()
  }

  private struct NeverConvertibleError: Error {}
}

// MARK: - Array

extension Array: ConvertibleToJSValue where Element: ConvertibleToJSValue {
  public func jsValue(in context: JSContext) throws(Element.ToJSValueFailure) -> JSValue {
    let array = JSValue(newArrayIn: context)!
    for element in self {
      array.invokeMethod("push", withArguments: [try element.jsValue(in: context)])
    }
    return array
  }
}

extension Array: ConvertibleFromJSValue where Element: ConvertibleFromJSValue {
  public init(jsValue: JSValue) throws {
    guard jsValue.isArray else { throw JSTypeMismatchError() }
    self.init()
    for i in 0..<jsValue.objectForKeyedSubscript("length").toInt32() {
      self.append(try Element(jsValue: jsValue.objectForKeyedSubscript(i)))
    }
  }
}

// MARK: - Dictionary

extension Dictionary: ConvertibleToJSValue where Key == String, Value: ConvertibleToJSValue {
  public func jsValue(in context: JSContext) throws(Value.ToJSValueFailure) -> JSValue {
    let object = JSValue(newObjectIn: context)!
    for (key, value) in self {
      object.setObject(try value.jsValue(in: context), forKeyedSubscript: key)
    }
    return object
  }
}

extension Dictionary: ConvertibleFromJSValue where Key == String, Value: ConvertibleFromJSValue {
  public init(jsValue: JSValue) throws {
    guard jsValue.isObject else { throw JSTypeMismatchError() }
    self.init()
    for key in jsValue.instanceVariableNames ?? [] {
      self[key] = try Value(jsValue: jsValue.objectForKeyedSubscript(key))
    }
  }
}

// MARK: - Set

extension Set: ConvertibleToJSValue where Element: ConvertibleToJSValue {
  public func jsValue(in context: JSContext) throws(Element.ToJSValueFailure) -> JSValue {
    let set = context.objectForKeyedSubscript("Set").construct(withArguments: [])!
    for element in self {
      set.invokeMethod("add", withArguments: [try element.jsValue(in: context)])
    }
    return set
  }
}

extension Set: ConvertibleFromJSValue where Element: ConvertibleFromJSValue {
  public init(jsValue: JSValue) throws {
    guard jsValue.isSet else { throw JSTypeMismatchError() }
    self.init()

    let values = jsValue.invokeMethod("values", withArguments: [])!
    while let element = values.invokeMethod("next", withArguments: []),
      !element.objectForKeyedSubscript("done").toBool()
    {
      self.insert(try Element(jsValue: element.objectForKeyedSubscript("value")))
    }
  }
}

extension JSValue {
  public var isSet: Bool {
    self.isInstanceOf(className: "Set")
  }
}
