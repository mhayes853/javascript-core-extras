import JavaScriptCore

// MARK: - JSValue

extension JSValue {
  /// Attempts to convert the value at the specified key.
  ///
  /// - Parameters:
  ///   - key: The key.
  ///   - type: The type of the value.
  /// - Returns: The converted value.
  public func value<Value: ConvertibleFromJSValue>(
    forKey key: Any,
    as type: Value.Type
  ) throws(Value.FromJSValueFailure) -> Value {
    try Value(jsValue: self.objectForKeyedSubscript(key))
  }
  
  /// Attempts to convert the value at the specified index.
  ///
  /// - Parameters:
  ///   - index: The index.
  ///   - type: The type of the converted value.
  /// - Returns: The converted value.
  public func value<Value: ConvertibleFromJSValue>(
    atIndex index: Int,
    as type: Value.Type
  ) throws(Value.FromJSValueFailure) -> Value {
    try Value(jsValue: self.objectAtIndexedSubscript(index))
  }
  
  /// Attempts to set the value for the specified key.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - key: The key.
  public func set<Value: ConvertibleToJSValue>(
    value: Value,
    forKey key: Any
  ) throws(Value.ToJSValueFailure) {
    self.setObject(try value.jsValue(in: self.context), forKeyedSubscript: key)
  }

  /// Attempts to set the value for the specified path.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - path: The path.
  public func set<Value: ConvertibleToJSValue>(
    value: Value,
    forPath path: String
  ) throws(Value.ToJSValueFailure) {
    self.setValue(try value.jsValue(in: self.context), forPath: path)
  }

  /// Attempts to set the value for the specified index.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - index: The index.
  public func set<Value: ConvertibleToJSValue>(
    value: Value,
    atIndex index: Int
  ) throws(Value.ToJSValueFailure) {
    self.setObject(try value.jsValue(in: self.context), atIndexedSubscript: index)
  }
}

// MARK: - JSContext

extension JSContext {
  /// Attempts to convert the value at the specified key.
  ///
  /// - Parameters:
  ///   - key: The key.
  ///   - type: The type of the value.
  /// - Returns: The converted value.
  public func value<Value: ConvertibleFromJSValue>(
    forKey key: Any,
    as type: Value.Type
  ) throws(Value.FromJSValueFailure) -> Value {
    try self.globalObject.value(forKey: key, as: type)
  }

  /// Attempts to convert the value at the specified index.
  ///
  /// - Parameters:
  ///   - index: The index.
  ///   - type: The type of the converted value.
  /// - Returns: The converted value.
  public func value<Value: ConvertibleFromJSValue>(
    atIndex index: Int,
    as type: Value.Type
  ) throws(Value.FromJSValueFailure) -> Value {
    try self.globalObject.value(atIndex: index, as: type)
  }

  /// Attempts to set the value for the specified key.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - key: The key.
  public func set<Value: ConvertibleToJSValue>(
    value: Value,
    forKey key: Any
  ) throws(Value.ToJSValueFailure) {
    try self.globalObject.set(value: value, forKey: key)
  }

  /// Attempts to set the value for the specified path.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - path: The path.
  public func set<Value: ConvertibleToJSValue>(
    value: Value,
    forPath path: String
  ) throws(Value.ToJSValueFailure) {
    try self.globalObject.set(value: value, forPath: path)
  }

  /// Attempts to set the value for the specified index.
  ///
  /// - Parameters:
  ///   - value: The value.
  ///   - index: The index.
  public func set<Value: ConvertibleToJSValue>(
    value: Value,
    atIndex index: Int
  ) throws(Value.ToJSValueFailure) {
    try self.globalObject.set(value: value, atIndex: index)
  }
}
