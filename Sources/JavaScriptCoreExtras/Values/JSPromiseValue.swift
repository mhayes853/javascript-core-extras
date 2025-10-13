import IssueReporting
@preconcurrency import JavaScriptCore

// MARK: - JSPromiseValue

public struct JSPromiseValue<Value: JSValueConvertible> {
  private let _jsValue: JSValue

  private init(_jsValue: JSValue) {
    self._jsValue = _jsValue
  }
}

// MARK: - Resolvers

extension JSPromiseValue where Value: Sendable {
  public static func withResolvers(in context: JSContext) -> (Self, Resolvers) {
    var resolvers: Resolvers?
    let promise = Self(in: context) { resolvers = $0 }
    return (promise, resolvers!)
  }

  public init(
    in context: JSContext,
    operation: @escaping @Sendable (JSActor<JSContext>) async throws -> Value
  ) {
    self.init(in: context) { resolvers in
      Task {
        do {
          await resolvers.resolve(try await operation(resolvers.contextActor))
        } catch {
          await resolvers.reject(error)
        }
      }
    }
  }

  public init(in context: JSContext, _ resolve: @escaping @Sendable (Resolvers) async -> Void) {
    self.init(in: context) { resolvers in
      Task { await resolve(resolvers) }
    }
  }

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
  public struct Resolvers: Sendable {
    let resolversActor:
      JSActor<(resolve: JSValue, reject: JSValue, context: JSContext, didFinish: Bool)>
    let contextActor: JSActor<JSContext>

    public func resolve(_ value: Value) async {
      await self.finish(with: .success(value))
    }

    public func reject(_ error: any Error) async {
      await self.finish(with: .failure(error))
    }

    public func finish(with result: Result<Value, any Error>) async {
      await self.resolversActor.withIsolation { @Sendable resolversActor in
        if resolversActor.value.didFinish {
          jsPromiseResolversMisuse()
        }
        do {
          let jsValue = try result.get().jsValue(in: resolversActor.value.context)
          resolversActor.value.resolve.call(withArguments: [jsValue])
        } catch {
          let jsValue = error._jsValue(in: resolversActor.value.context)
          resolversActor.value.reject.call(withArguments: [jsValue])
        }
        resolversActor.value.didFinish = true
      }
    }

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
  public static func resolve(
    _ value: Value,
    in context: JSContext
  ) throws(Value.ToJSValueFailure) -> JSPromiseValue<Value> {
    let value = try value.jsValue(in: context)
    return Self(_jsValue: JSValue(newPromiseResolvedWithResult: value, in: context))
  }

  public static func reject(_ error: any Error, in context: JSContext) -> JSPromiseValue<Value> {
    Self(_jsValue: JSValue(newPromiseRejectedWithReason: error._jsValue(in: context), in: context))
  }
}

// MARK: - Resolved Value

extension JSPromiseValue where Value: Sendable {
  public func resolvedValue(
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> Value {
    try await withUnsafeThrowingContinuation(isolation: isolation) { continuation in
      _ = self.then(
        onResolved: { value in
          continuation.resume(returning: value)
          return JSVoidValue()
        },
        onRejected: { error in
          continuation.resume(throwing: JSError(onCurrentExecutor: error))
          return JSVoidValue()
        }
      )
    }
  }
}

// MARK: - Then

extension JSPromiseValue {
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

  public func then<NewValue>(
    onResolved: ((Value) throws -> JSPromiseValue<NewValue>)? = nil,
    onRejected: ((JSValue) throws -> JSPromiseValue<NewValue>)? = nil
  ) -> JSPromiseValue<NewValue> {
    let resolved = onResolved.map { onResolved in
      let callback: @convention(block) (JSValue) -> JSValue = { jsValue in
        tryOperation(in: .current()) { try onResolved(Value(jsValue: jsValue)) }
      }
      return callback
    }
    let rejected = onRejected.map { onRejected in
      let callback: @convention(block) (JSValue) -> JSValue = { jsValue in
        tryOperation(in: .current()) { try onRejected(jsValue) }
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
    return JSPromiseValue<NewValue>(_jsValue: jsPromise)
  }
}

// MARK: - Catch

extension JSPromiseValue {
  public func `catch`<NewValue>(
    onRejected: ((JSValue) -> NewValue)? = nil
  ) -> JSPromiseValue<NewValue> {
    self.then(onResolved: nil, onRejected: onRejected)
  }

  public func `catch`<NewValue>(
    onRejected: ((JSValue) -> JSPromiseValue<NewValue>)? = nil
  ) -> JSPromiseValue<NewValue> {
    self.then(onResolved: nil, onRejected: onRejected)
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
    A JSPromiseValue was constructed on a thread without a current `JSVirtualMachineExecutor`.

    An executor is required to ensure that the promise is resolved or rejected on the proper \
    thread when performing asynchronous work inside the Promise.
    """
  )
}
