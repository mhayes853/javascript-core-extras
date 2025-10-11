import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("StandardLibrary+JSValueConvertible tests")
struct StandardLibraryJSValueConvertibleTests {
  @Test("Converts Array Of Values")
  func convertsArrayOfValues() throws {
    let context = JSContext()!
    let values = [42, 100]
    let jsValue = values.jsValue(in: context)

    expectNoDifference(jsValue.isArray, true)
    expectNoDifference(jsValue.objectAtIndexedSubscript(0).toInt32(), 42)
    expectNoDifference(jsValue.objectAtIndexedSubscript(1).toInt32(), 100)

    expectNoDifference(try [Int](jsValue: jsValue), values)
  }

  @Test("Converts Dictionary Of Values To Object")
  func convertsDictionaryOfValuesToObject() throws {
    let context = JSContext()!
    let values = ["a": 20, "b": 30]
    let jsValue = values.jsValue(in: context)

    expectNoDifference(jsValue.isObject, true)
    expectNoDifference(jsValue.objectForKeyedSubscript("a").toInt32(), 20)
    expectNoDifference(jsValue.objectForKeyedSubscript("b").toInt32(), 30)

    expectNoDifference(try [String: Int](jsValue: jsValue), values)
  }
}
