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
}
