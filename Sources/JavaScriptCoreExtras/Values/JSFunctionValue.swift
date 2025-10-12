// MARK: - JSFunctionValue

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
public struct JSFunctionValue<
  each Arguments: JSValueConvertible,
  Value: JSValueConvertible
> {
  private let function: (repeat (each Arguments)) throws -> Value

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
  public init(
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws -> Void
  ) where Value == JSVoidValue {
    self.function = { (args: repeat (each Arguments)) in
      try function(repeat each args)
      return JSVoidValue()
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
    do {
      guard jsArguments.count >= self.argsCount else {
        throw JSFunctionTooFewArgumentsError(expected: self.argsCount, got: jsArguments.count)
      }
      var i = 0
      func pop<T: ConvertibleFromJSValue>(_: T.Type) throws -> T {
        defer { i += 1 }
        return try T(jsValue: jsArguments[i])
      }
      return try self.function(repeat try pop((each Arguments).self)).jsValue(in: context)
    } catch {
      if let convertible = error as? any ConvertibleToJSValue,
        let exception = try? convertible.jsValue(in: context)
      {
        context.exception = exception
      } else {
        context.exception = JSValue(newErrorFromMessage: error.localizedDescription, in: context)
      }
      return JSValue(undefinedIn: context)
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
      guard let exception = jsValue.context.exception else {
        return try Value(jsValue: value)
      }

      if let executor = JSVirtualMachineExecutor.current() {
        // NB: This is safe because we're on the current executor thread, and the actor will
        // isolate the exception to that thread.
        throw JSError(
          valueActor: JSActor(UnsafeTransfer(value: exception).value, executor: executor)
        )
      } else {
        throw JSError()
      }
    }
  }
}

// MARK: - Is Function

extension JSValue {
  public var isFunction: Bool {
    self.isInstanceOf(className: "Function")
  }
}
