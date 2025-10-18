import IssueReporting
@preconcurrency import JavaScriptCore

// MARK: - JSPromiseValue

/// A data type that can be converted to and from a `JSValue` that represents a promise.
public struct JSPromiseValue<Value: JSValueConvertible> {
  private let _jsValue: JSValue

  /// The ``JSVirtualMachineExecutor`` used by this promise.
  public let executor: JSVirtualMachineExecutor

  private init(_jsValue: JSValue, executor: JSVirtualMachineExecutor? = .current()) {
    self._jsValue = _jsValue
    guard let executor else {
      jsPromiseNoCurrentExecutor()
    }
    self.executor = executor
  }
}

// MARK: - Resolvers

extension JSPromiseValue where Value: Sendable {
  /// Returns a promise with its ``Resolvers``.
  ///
  /// > Warning: This method must be called on a thread with a current ``JSVirtualMachineExecutor``.
  ///
  /// - Parameter context: The context to create the promise in.
  /// - Returns: A promise with its resolvers.
  public static func withResolvers(in context: JSContext) -> (Self, Resolvers) {
    var resolvers: Resolvers?
    let promise = Self(in: context) { resolvers = $0 }
    return (promise, resolvers!)
  }

  /// Creates a promise.
  ///
  /// > Warning: This method must be called on a thread with a current ``JSVirtualMachineExecutor``.
  ///
  /// - Parameters:
  ///   - context: The context to create the promise in.
  ///   - operation: The asynchronous operation to run as the promise body.
  public init(
    in context: JSContext,
    operation: @escaping @Sendable (JSActor<JSContext>) async throws -> Value
  ) {
    self.init(in: context) { resolvers in
      Task {
        do {
          try await resolvers.resolve(operation(resolvers.contextActor))
        } catch {
          await resolvers.reject(error)
        }
      }
    }
  }

  /// Creates a promise.
  ///
  /// > Warning: This method must be called on a thread with a current ``JSVirtualMachineExecutor``.
  ///
  /// - Parameters:
  ///   - context: The context to create the promise in.
  ///   - resolve: The asynchronous operation to run as the promise body.
  public init(in context: JSContext, _ resolve: @escaping @Sendable (Resolvers) async -> Void) {
    self.init(in: context) { resolvers in
      Task { await resolve(resolvers) }
    }
  }

  /// Creates a promise.
  ///
  /// > Warning: This method must be called on a thread with a current ``JSVirtualMachineExecutor``.
  ///
  /// - Parameters:
  ///   - context: The context to create the promise in.
  ///   - resolve: The operation to run as the promise body.
  public init(in context: JSContext, _ resolve: (Resolvers) -> Void) {
    let promise = withoutActuallyEscaping(
      { (_resolve: JSValue?, reject: JSValue?) in
        guard let executor = JSVirtualMachineExecutor.current() else {
          jsPromiseNoCurrentExecutor()
        }
        let resolvers = Resolvers(
          resolversActor: JSActor(
            (resolve: _resolve!, reject: reject!, context: context, didFinish: false),
            executor: executor
          ),
          contextActor: JSActor(context, executor: executor)
        )
        resolve(resolvers)
      },
      do: { JSValue(newPromiseIn: context, fromExecutor: $0) }
    )
    self.init(_jsValue: promise!)
  }
}

extension JSPromiseValue where Value: Sendable {
  /// A data type that enables resolving and rejecting a ``JSPromiseValue``.
  public struct Resolvers: Sendable {
    typealias State = (resolve: JSValue, reject: JSValue, context: JSContext, didFinish: Bool)
    let resolversActor: JSActor<State>
    let contextActor: JSActor<JSContext>

    /// Resolves the promise with the specified `value`.
    ///
    /// - Parameter value: The value to resolve.
    public func resolve(_ value: Value) async throws(Value.ToJSValueFailure) {
      try await self.finish(with: .success(value))
    }

    /// Resolves the promise with the specified `value`.
    ///
    /// - Parameter value: The value to resolve.
    public func resolve(_ value: JSValue) async {
      await self.resolversActor.withIsolation { @Sendable resolversActor in
        self.markFinished(state: &resolversActor.value)
        _ = resolversActor.value.resolve.call(withArguments: [value])
      }
    }

    /// Rejects the promise with the specified `error`.
    ///
    /// - Parameter error: The error to reject with.
    public func reject(_ error: any Error) async {
      try! await self.finish(with: .failure(error))
    }

    /// Rejects the promise with the specified `error`.
    ///
    /// - Parameter error: The error to reject with.
    public func reject(_ error: JSValue) async {
      await self.resolversActor.withIsolation { @Sendable resolversActor in
        self.markFinished(state: &resolversActor.value)
        _ = resolversActor.value.reject.call(withArguments: [error])
      }
    }

    /// Resolves or rejects the promise based on the specified `result`.
    ///
    /// - Parameter result: The result to finish the promise with.
    public func finish(
      with result: Result<Value, any Error>
    ) async throws(Value.ToJSValueFailure) {
      try await self.resolversActor
        .withIsolation { @Sendable resolversActor throws(Value.ToJSValueFailure) in
          self.markFinished(state: &resolversActor.value)
          switch result {
          case .success(let value):
            let jsValue = try value.jsValue(in: resolversActor.value.context)
            resolversActor.value.resolve.call(withArguments: [jsValue])
          case .failure(let error):
            let jsValue = error._jsValue(in: resolversActor.value.context)
            resolversActor.value.reject.call(withArguments: [jsValue])
          }
        }
    }

    private func markFinished(state: inout State) {
      if state.didFinish {
        jsPromiseResolversMisuse()
      }
      state.didFinish = true
    }

    /// Allows access to the underlying `JSContext` of the promise.
    ///
    /// - Parameter operation: The operation to run with the context.
    /// - Returns: Whatever `operation` returns.
    public func withContext<T, E: Error>(
      operation: @Sendable (JSContext) throws(E) -> sending T
    ) async throws(E) -> sending T {
      try await contextActor.withIsolation { @Sendable contextActor throws(E) in
        try operation(contextActor.value)
      }
    }
  }
}

// MARK: - Static Initializer

extension JSPromiseValue {
  /// Creates a promise that resolves to the specified `value`.
  ///
  /// > Warning: This method must be called on a thread with a current ``JSVirtualMachineExecutor``.
  ///
  /// - Parameters:
  ///   - value: The value to resolve.
  ///   - context: The context to resolve the value in.
  /// - Returns: A promise.
  public static func resolve(
    _ value: Value,
    in context: JSContext
  ) throws(Value.ToJSValueFailure) -> JSPromiseValue<Value> {
    .resolve(try value.jsValue(in: context))
  }

  /// Creates a promise that resolves to the specified `value`.
  ///
  /// > Warning: This method must be called on a thread with a current ``JSVirtualMachineExecutor``.
  ///
  /// - Parameters:
  ///   - value: The value to resolve.
  /// - Returns: A promise.
  public static func resolve(_ value: JSValue) -> JSPromiseValue<Value> {
    Self(_jsValue: JSValue(newPromiseResolvedWithResult: value, in: value.context))
  }

  /// Creates a promise that rejects to the specified `error`.
  ///
  /// > Warning: This method must be called on a thread with a current ``JSVirtualMachineExecutor``.
  ///
  /// - Parameters:
  ///   - error: The error to reject with.
  ///   - context: The context to reject with the error.
  /// - Returns: A promise.
  public static func reject(_ error: any Error, in context: JSContext) -> JSPromiseValue<Value> {
    .reject(error._jsValue(in: context))
  }

  /// Creates a promise that rejects to the specified `error`.
  ///
  /// > Warning: This method must be called on a thread with a current ``JSVirtualMachineExecutor``.
  ///
  /// - Parameters:
  ///   - error: The error to reject with.
  /// - Returns: A promise.
  public static func reject(_ error: JSValue) -> JSPromiseValue<Value> {
    Self(_jsValue: JSValue(newPromiseRejectedWithReason: error, in: error.context))
  }
}

// MARK: - Resolved Value

extension JSPromiseValue where Value: Sendable {
  /// Waits for the resolved value of this promise.
  ///
  /// - Parameter isolation: The isolation context.
  /// - Returns: The resolved value.
  public func resolvedValue(
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> Value {
    try await self.resolvedJSvalue(isolation: isolation)
      .withIsolation { @Sendable in try Value(jsValue: $0.value) }
  }

  /// Waits for the resolved `JSValue` of this promise.
  ///
  /// - Parameter isolation: The isolation context.
  /// - Returns: The resolved value.
  public func resolvedJSvalue(
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> JSActor<JSValue> {
    try await withUnsafeThrowingContinuation(isolation: isolation) { continuation in
      Task {
        await self.executor.withVirtualMachine { _ in
          _ = self.then(
            JSUndefinedValue.self,
            onResolved: { value in
              continuation.resume(returning: JSActor(value, executor: self.executor))
              return JSUndefinedValue().jsValue(in: .current())
            },
            onRejected: { error in
              continuation.resume(throwing: JSError(onCurrentExecutor: error))
              return JSUndefinedValue().jsValue(in: .current())
            }
          )
        }
      }
    }
  }
}

// MARK: - Then

extension JSPromiseValue {
  /// Invokes `.then` on the promise.
  ///
  /// - Parameters:
  ///   - onResolved: A transform for the resolved value.
  ///   - onRejected: A transform for the rejected reason.
  /// - Returns: A transformed promise.
  public func then<NewValue>(
    onResolved: ((Value) throws -> NewValue)? = nil,
    onRejected: ((JSValue) throws -> NewValue)? = nil,
  ) -> JSPromiseValue<NewValue> {
    self.then(
      onResolved: onResolved.map { onResolved in
        return { try .resolve(onResolved($0), in: .current()) }
      },
      onRejected: onRejected.map { onRejected in
        return { try .resolve(onRejected($0), in: .current()) }
      }
    )
  }

  /// Invokes `.then` on the promise.
  ///
  /// - Parameters:
  ///   - onResolved: A transform for the resolved value.
  ///   - onRejected: A transform for the rejected reason.
  /// - Returns: A transformed promise.
  @_disfavoredOverload
  public func then<NewValue>(
    onResolved: ((Value) throws -> JSPromiseValue<NewValue>)? = nil,
    onRejected: ((JSValue) throws -> NewValue)? = nil
  ) -> JSPromiseValue<NewValue> {
    self.then(
      onResolved: onResolved,
      onRejected: onRejected.map { onRejected in
        return { try .resolve(onRejected($0), in: .current()) }
      }
    )
  }

  /// Invokes `.then` on the promise.
  ///
  /// - Parameters:
  ///   - onResolved: A transform for the resolved value.
  ///   - onRejected: A transform for the rejected reason.
  /// - Returns: A transformed promise.
  @_disfavoredOverload
  public func then<NewValue>(
    onResolved: ((Value) throws -> NewValue)? = nil,
    onRejected: ((JSValue) throws -> JSPromiseValue<NewValue>)? = nil
  ) -> JSPromiseValue<NewValue> {
    self.then(
      onResolved: onResolved.map { onResolved in
        return { try .resolve(onResolved($0), in: .current()) }
      },
      onRejected: onRejected
    )
  }

  /// Invokes `.then` on the promise.
  ///
  /// - Parameters:
  ///   - onResolved: A transform for the resolved value.
  ///   - onRejected: A transform for the rejected reason.
  /// - Returns: A transformed promise.
  public func then<NewValue>(
    onResolved: ((Value) throws -> JSPromiseValue<NewValue>)? = nil,
    onRejected: ((JSValue) throws -> JSPromiseValue<NewValue>)? = nil
  ) -> JSPromiseValue<NewValue> {
    self.then(
      NewValue.self,
      onResolved: onResolved.map { onResolved in
        return { try onResolved(Value(jsValue: $0)).jsValue(in: .current()) }
      },
      onRejected: onRejected.map { onRejected in
        return { try onRejected($0).jsValue(in: .current()) }
      }
    )
  }

  /// Invokes `.then` on the promise.
  ///
  /// - Parameters:
  ///   - type: The new value type of the transformed promise.
  ///   - onResolved: A transform for the resolved value.
  ///   - onRejected: A transform for the rejected reason.
  /// - Returns: A transformed promise.
  public func then<NewValue>(
    _ type: NewValue.Type,
    onResolved: ((JSValue) throws -> JSValue)? = nil,
    onRejected: ((JSValue) throws -> JSValue)? = nil
  ) -> JSPromiseValue<NewValue> {
    guard JSVirtualMachineExecutor.current() === self.executor else {
      jsPromiseInvalidExecutor()
    }
    let resolved = onResolved.map { onResolved in
      let callback: @convention(block) (JSValue) -> JSValue = { jsValue in
        tryJSOperation(in: .current()) { try onResolved(jsValue) }
      }
      return callback
    }
    let rejected = onRejected.map { onRejected in
      let callback: @convention(block) (JSValue) -> JSValue = { jsValue in
        tryJSOperation(in: .current()) { try onRejected(jsValue) }
      }
      return callback
    }
    let jsPromise = self._jsValue.invokeMethod(
      "then",
      withArguments: [
        unsafeBitCast(resolved, to: JSValue.self),
        unsafeBitCast(rejected, to: JSValue.self)
      ]
    )!
    return JSPromiseValue<NewValue>(_jsValue: jsPromise, executor: self.executor)
  }
}

// MARK: - Catch

extension JSPromiseValue {
  /// Invokes `.catch` on the promise.
  ///
  /// - Parameter onRejected: A transform for the rejected reason.
  /// - Returns: A transformed promise.
  public func `catch`<NewValue>(
    onRejected: ((JSValue) throws -> NewValue)? = nil
  ) -> JSPromiseValue<NewValue> {
    self.then(onResolved: nil, onRejected: onRejected)
  }

  /// Invokes `.catch` on the promise.
  ///
  /// - Parameter onRejected: A transform for the rejected reason.
  /// - Returns: A transformed promise.
  public func `catch`<NewValue>(
    onRejected: ((JSValue) throws -> JSPromiseValue<NewValue>)? = nil
  ) -> JSPromiseValue<NewValue> {
    self.then(onResolved: nil, onRejected: onRejected)
  }

  /// Invokes `.catch` on the promise.
  ///
  /// - Parameters:
  ///   - type: The new value type of the transformed promise.
  ///   - onRejected: A transform for the rejected reason.
  /// - Returns: A transformed promise.
  public func `catch`<NewValue>(
    _ type: NewValue.Type,
    onRejected: ((JSValue) throws -> JSValue)? = nil
  ) -> JSPromiseValue<NewValue> {
    self.then(type, onResolved: nil, onRejected: onRejected)
  }
}

// MARK: - ConvertibleToJSValue

extension JSPromiseValue: ConvertibleToJSValue {
  public func jsValue(in context: JSContext) throws -> JSValue {
    guard self._jsValue.context.virtualMachine === context.virtualMachine else {
      throw JSDifferentVirtualMachinesError()
    }
    return self._jsValue
  }
}

private struct JSDifferentVirtualMachinesError: Error {}

// MARK: - ConvertibleFromJSValue

extension JSPromiseValue: ConvertibleFromJSValue {
  public init(jsValue: JSValue) throws {
    guard jsValue.isPromise else { throw JSTypeMismatchError() }
    self.init(_jsValue: jsValue)
  }
}

// MARK: - Is Promise

extension JSValue {
  /// Whether or not this value is an instance of a Promise.
  public var isPromise: Bool {
    self.isInstanceOf(className: "Promise")
  }
}

// MARK: - Helpers

private func jsPromiseResolversMisuse() {
  reportIssue(
    """
    A JSPromiseValue Resolvers instance was resolved or rejected more than once.

    Resolving or rejecting more than once will have no effect on the resolved value or rejected \
    reason.
    """
  )
}

private func jsPromiseNoCurrentExecutor() -> Never {
  fatalError(
    """
    A JSPromiseValue was constructed on a thread without a current running \
    `JSVirtualMachineExecutor`.

    A running executor is required to ensure that the promise is resolved or rejected on the \
    proper thread when performing asynchronous work inside the Promise.
    """
  )
}

private func jsPromiseInvalidExecutor() -> Never {
  fatalError(
    """
    `.then` on a JSPromiseValue was invoked on different thread than its executor.

    Since JSValue instances can only be accessed safely from the thread they were created on, \
    `.then` must be invoked on the same thread as the executor.
    """
  )
}
