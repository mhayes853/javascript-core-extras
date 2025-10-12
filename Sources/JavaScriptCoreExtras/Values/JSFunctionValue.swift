// MARK: - JSFunctionValue

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
public struct JSFunctionValue<
  each Arguments: ConvertibleFromJSValue,
  Value: ConvertibleToJSValue,
  Failure: Error
> {
  private let function: (repeat (each Arguments)) throws(Failure) -> Value

  public init(
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws(Failure) -> Value
  ) {
    self.function = function
  }

  public init(
    _ argumentTypes: repeat (each Arguments).Type,
    function: @escaping (repeat (each Arguments)) throws(Failure) -> Void
  ) where Value == JSVoidValue {
    self.function = { (args: repeat (each Arguments)) throws(Failure) in
      try function(repeat each args)
      return JSVoidValue()
    }
  }

  public func callAsFunction(_ arguments: repeat (each Arguments)) throws(Failure) -> Value {
    try self.function(repeat each arguments)
  }
}

// MARK: - JSValueConvertible

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
