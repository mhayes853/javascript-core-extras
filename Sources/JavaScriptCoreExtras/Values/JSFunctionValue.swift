// MARK: - JSFunctionValue

/// A strongly typed function value that can be converted to and from a `JSValue`.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
public struct JSFunctionValue<
  each Arguments: JSValueConvertible,
  Value: JSValueConvertible
> {
  private let function: (repeat (each Arguments)) throws -> Value

  /// Creates a function.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types of the function.
  ///   - function: The function body.
  public init(
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Value
  ) {
    self.function = function
  }

  public func callAsFunction(_ arguments: repeat (each Arguments)) throws -> Value {
    try self.function(repeat each arguments)
  }
}

// MARK: - Void

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
extension JSFunctionValue {
  /// Creates a void function.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types of the function.
  ///   - function: The function body.
  public init(
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Void
  ) where Value == JSUndefinedValue {
    self.function = { (args: repeat (each Arguments)) in
      try function(repeat each args)
      return JSUndefinedValue()
    }
  }
}

// MARK: - ConvertibleToJSValue

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
extension JSFunctionValue: ConvertibleToJSValue {
  public func jsValue(in context: JSContext) -> JSValue {
    let block: @convention(block) () -> JSValue = {
      self(jsArguments: JSContext.currentArguments() as! [JSValue], in: .current())
    }
    return JSValue(object: block, in: context)
  }

  private func callAsFunction(jsArguments: [JSValue], in context: JSContext) -> JSValue {
    tryOperation(in: context) {
      guard jsArguments.count >= self.argsCount else {
        throw JSFunctionTooFewArgumentsError(expected: self.argsCount, got: jsArguments.count)
      }
      var i = 0
      func pop<T: ConvertibleFromJSValue>(_: T.Type) throws -> T {
        defer { i += 1 }
        return try T(jsValue: jsArguments[i])
      }
      return try self.function(repeat try pop((each Arguments).self))
    }
  }

  private var argsCount: Int {
    var count = 0
    for _ in repeat (each Arguments).self {
      count += 1
    }
    return count
  }
}

private struct JSFunctionTooFewArgumentsError: Error, ConvertibleToJSValue {
  let expected: Int
  let got: Int

  func jsValue(in context: JSContext) -> JSValue {
    let argsMessage =
      self.expected > 1
      ? "\(expected) arguments required, but only \(got) present."
      : "\(expected) argument required, but only \(got) present."
    return .typeError(message: "Failed to execute function: \(argsMessage)", in: context)
  }
}

// MARK: - ConvertibleFromJSValue

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
extension JSFunctionValue: ConvertibleFromJSValue {
  public init(jsValue: JSValue) throws {
    guard jsValue.isFunction else { throw JSTypeMismatchError() }

    self.init(repeat (each Arguments).self) { (args: repeat (each Arguments)) -> Value in
      var jsArgs = [JSValue]()
      for arg in repeat each args {
        jsArgs.append(try arg.jsValue(in: jsValue.context))
      }
      guard let value = jsValue.call(withArguments: jsArgs) else {
        throw JSError()
      }
      if let exception = jsValue.context.exception {
        throw JSError(onCurrentExecutor: exception)
      }
      return try Value(jsValue: value)
    }
  }
}

// MARK: - Is Function

extension JSValue {
  /// Whether or not this value is a function.
  public var isFunction: Bool {
    self.isInstanceOf(className: "Function")
  }
}

// MARK: - Helpers

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
extension JSValue {
  /// Sets a function for the specified key.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - key: The key.
  public func setFunction<each Arguments: JSValueConvertible, Value: JSValueConvertible>(
    forKey key: Any,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Value,
  ) {
    self.set(
      value: JSFunctionValue<repeat (each Arguments), Value>(
        repeat (each argumentTypes),
        function: function
      ),
      forKey: key
    )
  }

  /// Sets a function for the specified key.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - key: The key.
  public func setFunction<each Arguments: JSValueConvertible>(
    forKey key: Any,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Void,
  ) {
    self.set(
      value: JSFunctionValue<repeat (each Arguments), JSUndefinedValue>(
        repeat (each argumentTypes),
        function: function
      ),
      forKey: key
    )
  }

  /// Sets a function for the specified index.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - index: The index.
  public func setFunction<each Arguments: JSValueConvertible, Value: JSValueConvertible>(
    atIndex index: Int,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Value,
  ) {
    self.set(
      value: JSFunctionValue<repeat (each Arguments), Value>(
        repeat (each argumentTypes),
        function: function
      ),
      atIndex: index
    )
  }

  /// Sets a function for the specified index.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - index: The index.
  public func setFunction<each Arguments: JSValueConvertible>(
    atIndex index: Int,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Void
  ) {
    self.set(
      value: JSFunctionValue<repeat (each Arguments), JSUndefinedValue>(
        repeat (each argumentTypes),
        function: function
      ),
      atIndex: index
    )
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
extension JSContext {
  /// Sets a function for the specified key.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - key: The key.
  public func setFunction<each Arguments: JSValueConvertible, Value: JSValueConvertible>(
    forKey key: Any,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Value,
  ) {
    self.globalObject.setFunction(forKey: key, repeat (each argumentTypes), function: function)
  }

  /// Sets a function for the specified key.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - key: The key.
  public func setFunction<each Arguments: JSValueConvertible>(
    forKey key: Any,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Void,
  ) {
    self.globalObject.setFunction(forKey: key, repeat (each argumentTypes), function: function)
  }

  /// Sets a function for the specified index.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - index: The index.
  public func setFunction<each Arguments: JSValueConvertible, Value: JSValueConvertible>(
    atIndex index: Int,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Value,
  ) {
    self.globalObject.setFunction(atIndex: index, repeat (each argumentTypes), function: function)
  }

  /// Sets a function for the specified index.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - index: The index.
  public func setFunction<each Arguments: JSValueConvertible>(
    atIndex index: Int,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Void,
  ) {
    self.globalObject.setFunction(atIndex: index, repeat (each argumentTypes), function: function)
  }
}
