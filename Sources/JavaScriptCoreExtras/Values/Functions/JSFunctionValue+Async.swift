@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
extension JSFunctionValue where repeat (each Arguments): Sendable {
  /// Creates an async function.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types of the function.
  ///   - function: The function body.
  public static func `async`<V: Sendable>(
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> V
  ) -> Self where Value == JSPromiseValue<V> {
    Self(repeat each argumentTypes) { (args: repeat (each Arguments)) in
      JSPromiseValue(in: .current()) { contextActor in
        try await function(contextActor, repeat each args)
      }
    }
  }

  /// Creates an async function.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types of the function.
  ///   - function: The function body.
  public static func `async`(
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Void
  ) -> Self where Value == JSPromiseValue<JSUndefinedValue> {
    .async(repeat each argumentTypes) { (contextActor, args: repeat (each Arguments)) in
      try await function(contextActor, repeat each args)
      return JSUndefinedValue()
    }
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
  public func setAsyncFunction<
    each Arguments: JSValueConvertible & Sendable,
    Value: JSValueConvertible & Sendable
  >(
    forKey key: Any,
    _ argumentTypes: repeat (each Arguments).Type,
    function:
      @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Value,
  ) {
    self.set(
      value: JSFunctionValue<repeat (each Arguments), JSPromiseValue<Value>>
        .async(repeat (each argumentTypes), function: function),
      forKey: key
    )
  }

  /// Sets a function for the specified key.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - key: The key.
  public func setAsyncFunction<each Arguments: JSValueConvertible & Sendable>(
    forKey key: Any,
    _ argumentTypes: repeat (each Arguments).Type,
    function:
      @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Void,
  ) {
    self.set(
      value: JSFunctionValue<repeat (each Arguments), JSPromiseValue<JSUndefinedValue>>
        .async(repeat (each argumentTypes), function: function),
      forKey: key
    )
  }

  /// Sets a function for the specified index.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - index: The index.
  public func setAsyncFunction<
    each Arguments: JSValueConvertible & Sendable,
    Value: JSValueConvertible & Sendable
  >(
    atIndex index: Int,
    _ argumentTypes: repeat (each Arguments).Type,
    function:
      @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Value,
  ) {
    self.set(
      value: JSFunctionValue<repeat (each Arguments), JSPromiseValue<Value>>
        .async(repeat (each argumentTypes), function: function),
      atIndex: index
    )
  }

  /// Sets a function for the specified index.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - index: The index.
  public func setAsyncFunction<each Arguments: JSValueConvertible & Sendable>(
    atIndex index: Int,
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Void
  ) {
    self.set(
      value: JSFunctionValue<repeat (each Arguments), JSPromiseValue<JSUndefinedValue>>
        .async(repeat (each argumentTypes), function: function),
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
  public func setAsyncFunction<
    each Arguments: JSValueConvertible & Sendable,
    Value: JSValueConvertible & Sendable
  >(
    forKey key: Any,
    _ argumentTypes: repeat (each Arguments).Type,
    function:
      @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Value,
  ) {
    self.globalObject.setAsyncFunction(forKey: key, repeat (each argumentTypes), function: function)
  }

  /// Sets a function for the specified key.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - key: The key.
  public func setAsyncFunction<each Arguments: JSValueConvertible & Sendable>(
    forKey key: Any,
    _ argumentTypes: repeat (each Arguments).Type,
    function:
      @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Void,
  ) {
    self.globalObject.setAsyncFunction(forKey: key, repeat (each argumentTypes), function: function)
  }

  /// Sets a function for the specified index.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - index: The index.
  public func setAsyncFunction<
    each Arguments: JSValueConvertible & Sendable,
    Value: JSValueConvertible & Sendable
  >(
    atIndex index: Int,
    _ argumentTypes: repeat (each Arguments).Type,
    function:
      @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Value,
  ) {
    self.globalObject.setAsyncFunction(
      atIndex: index,
      repeat (each argumentTypes),
      function: function
    )
  }

  /// Sets a function for the specified index.
  ///
  /// - Parameters:
  ///   - argumentTypes: The argument types.
  ///   - function: The function body.
  ///   - index: The index.
  public func setAsyncFunction<each Arguments: JSValueConvertible & Sendable>(
    atIndex index: Int,
    _ argumentTypes: repeat (each Arguments).Type,
    function:
      @escaping @Sendable (JSActor<JSContext>, repeat (each Arguments)) async throws -> Void,
  ) {
    self.globalObject.setAsyncFunction(
      atIndex: index,
      repeat (each argumentTypes),
      function: function
    )
  }
}
