import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("JSFunctionValue tests")
struct JSFunctionValueTests {
  @Test("Converted To JSValue, Void")
  func convertedToJSValueVoid() throws {
    var count = 0
    let f = JSFunctionValue(Int.self) { count += $0 }

    let context = JSContext()!
    let jsValue = f.jsValue(in: context)

    let value = jsValue.call(withArguments: [10])

    expectNoDifference(context.exception, nil)
    expectNoDifference(value?.isUndefined, true)
    expectNoDifference(count, 10)
  }

  @Test("Converted To JSValue, Non-Void")
  func convertedToJSValueNonVoid() throws {
    let f = JSFunctionValue(Int.self, String.self) {
      "The string is \($1) and number is \($0)"
    }

    let context = JSContext()!
    let jsValue = f.jsValue(in: context)

    let value = jsValue.call(withArguments: [10, "blob"])

    expectNoDifference(context.exception, nil)
    expectNoDifference(value?.isString, true)
    expectNoDifference(value?.toString(), "The string is blob and number is 10")
  }

  @Test("Converted To JSValue, Too Many Args")
  func convertedToJSValueTooManyArgs() throws {
    let f = JSFunctionValue(Int.self, String.self) {
      "The string is \($1) and number is \($0)"
    }

    let context = JSContext()!
    let jsValue = f.jsValue(in: context)

    let value = jsValue.call(withArguments: [10, "blob", true])

    expectNoDifference(context.exception, nil)
    expectNoDifference(value?.isString, true)
    expectNoDifference(value?.toString(), "The string is blob and number is 10")
  }

  @Test("Converted To JSValue, Too Few Args")
  func convertedToJSValueTooFewArgs() throws {
    let f = JSFunctionValue(Int.self, String.self) {
      "The string is \($1) and number is \($0)"
    }

    let context = JSContext()!
    let jsValue = f.jsValue(in: context)

    let value = jsValue.call(withArguments: [10])

    expectNoDifference(context.exception.isUndefined, false)
    expectNoDifference(context.exception.isObject, true)
    expectNoDifference(
      context.exception.objectForKeyedSubscript("message").toString(),
      "Failed to execute function: 2 arguments required, but only 1 present."
    )
    expectNoDifference(value?.isUndefined, true)
  }

  @Test("Converted To JSValue, Exception Object Is Determined By Error")
  func convertedToJSValueExceptionObjectIsDeterminedByError() throws {
    struct SomeError: Error, ConvertibleToJSValue {
      func jsValue(in context: JSContext) -> JSValue {
        JSValue(object: "blob", in: context)
      }
    }

    let f = JSFunctionValue(Int.self, String.self) { _, _ in throw SomeError() }

    let context = JSContext()!
    let jsValue = f.jsValue(in: context)

    let value = jsValue.call(withArguments: [10, "20"])

    expectNoDifference(context.exception.isUndefined, false)
    expectNoDifference(context.exception.toString(), "blob")
    expectNoDifference(value?.isUndefined, true)
  }

  @Test("Throws When Trying To Construct From Non-Function Value")
  func throwsWhenTryingToConstructFromNonFunctionValue() throws {
    let value = JSValue(object: "blob", in: JSContext()!)!
    #expect(throws: Error.self) {
      try JSFunctionValue<Int, String>(jsValue: value)
    }
  }

  @Test("Constructs From Function Value")
  func constructsFromFunctionValue() throws {
    let context = JSContext()!
    let jsValue = context.evaluateScript(
      """
      function increment(n) {
        return n + 1
      }

      increment
      """
    )

    let f = try JSFunctionValue<Int, Int>(jsValue: jsValue!)
    expectNoDifference(try f(10), 11)
  }

  @Test("Passes Swift Value To JS")
  func passesSwiftValueToJS() throws {
    struct Value: Codable, JSValueConvertible {
      let name: String
    }

    let context = JSContext()!
    let jsValue = context.evaluateScript(
      """
      function hello(obj) {
        return `Hello ${obj.name}`
      }

      hello
      """
    )

    let f = try JSFunctionValue<Value, String>(jsValue: jsValue!)
    expectNoDifference(try f(Value(name: "blob")), "Hello blob")
  }

  @Test("Forwards JS Errors")
  func forwardsJSErrors() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)

    let message = "This is an error."
    let contextActor = await pool.executor().contextActor()
    let error = try await contextActor.withIsolation { @Sendable contextActor in
      let jsValue = contextActor.value.evaluateScript(
        """
        function hello() {
          throw new Error("\(message)")
        }

        hello
        """
      )

      let f = try JSFunctionValue<JSUndefinedValue, Never>(jsValue: jsValue!)
      return #expect(throws: JSError.self) {
        try f(JSUndefinedValue())
      }
    }
    await error?.valueActor?
      .withIsolation { @Sendable in
        expectNoDifference($0.value.toString(), "Error: \(message)")
      }
  }

  @Test("Forwards JS Errors As Nil When No Current Executor")
  func forwardsJSErrorsAsNilWhenNoCurrentExecutor() async throws {
    let message = "This is an error."
    let context = JSContext()!
    let jsValue = context.evaluateScript(
      """
      function hello() {
        throw new Error("\(message)")
      }

      hello
      """
    )

    let f = try JSFunctionValue<JSUndefinedValue, Never>(jsValue: jsValue!)
    let error = #expect(throws: JSError.self) {
      try f(JSUndefinedValue())
    }
    expectNoDifference(error?.valueActor == nil, true)
  }

  @Test("Async Function")
  func asyncFunction() async throws {
    try await withContextActor { contextActor in
      contextActor.value.setAsyncFunction(forKey: "work", Int.self) { contextActor, i in
        i + 10
      }
      let promise = contextActor.value.evaluateScript(
        """
        work(100)
        """
      )!
      let promiseValue = try JSPromiseValue<Int>(jsValue: promise)
      let n = try await promiseValue.resolvedValue()
      expectNoDifference(n, 110)
    }
  }

  @Test("Async Function With No Arguments")
  func asyncFunctionWithNoArguments() async throws {
    try await withContextActor { contextActor in
      contextActor.value.setAsyncFunction(forKey: "work") { _ in
        110
      }
      let promise = contextActor.value.evaluateScript(
        """
        work()
        """
      )!
      let promiseValue = try JSPromiseValue<Int>(jsValue: promise)
      let n = try await promiseValue.resolvedValue()
      expectNoDifference(n, 110)
    }
  }

  @Test("Async Function Context Access")
  func asyncFunctionWithContextAccess() async throws {
    try await withContextActor { contextActor in
      contextActor.value.setAsyncFunction(forKey: "work") { contextActor in
        try await contextActor.withIsolation { @Sendable in
          try $0.value.value(forKey: "value", as: Int.self)
        }
      }
      let promise = contextActor.value.evaluateScript(
        """
        var value = 110
        work()
        """
      )!
      let promiseValue = try JSPromiseValue<Int>(jsValue: promise)
      let n = try await promiseValue.resolvedValue()
      expectNoDifference(n, 110)
    }
  }

  @Test("Async Function Rejects When Error Thrown")
  func asyncFunctionRejectsWhenErrorThrown() async throws {
    struct SomeError: Error {}
    try await withContextActor { contextActor in
      contextActor.value.setAsyncFunction(forKey: "work") { _ in
        throw SomeError()
      }
      let promise = contextActor.value.evaluateScript(
        """
        work()
        """
      )!
      let promiseValue = try JSPromiseValue<Int>(jsValue: promise)
      await #expect(throws: JSError.self) {
        try await promiseValue.resolvedValue()
      }
    }
  }
}
