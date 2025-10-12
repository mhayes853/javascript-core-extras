import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("Foundation+JSValueConvertible tests")
struct FoundationJSValueConvertibleTests {
  @Test("Converts Date")
  func convertsDate() throws {
    let context = JSContext()!
    let date = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970).rounded())
    let jsValue = date.jsValue(in: context)

    expectNoDifference(jsValue.isDate, true)
    expectNoDifference(jsValue.toDate(), date)

    expectNoDifference(try Date(jsValue: jsValue), date)
  }

  @Test("Converts UUID")
  func convertsUUID() throws {
    let context = JSContext()!
    let uuid = UUID()
    let jsValue = uuid.jsValue(in: context)

    expectNoDifference(jsValue.isString, true)
    expectNoDifference(jsValue.toString(), uuid.uuidString)

    expectNoDifference(try UUID(jsValue: jsValue), uuid)
  }

  @Test("Cannot Convert Invalid UUID")
  func cannotConvertInvalidUUID() throws {
    let context = JSContext()!
    #expect(throws: Error.self) {
      try UUID(jsValue: JSValue(object: "invalid-uuid-string", in: context))
    }
  }
}
