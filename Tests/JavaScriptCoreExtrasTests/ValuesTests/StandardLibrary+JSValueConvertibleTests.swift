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

  @Test("Converts Set Of Values")
  func convertsSetOfValues() throws {
    let context = JSContext()!
    let values = Set([20, 30])
    let jsValue = values.jsValue(in: context)

    expectNoDifference(jsValue.isSet, true)
    expectNoDifference(jsValue.isObject, true)
    expectNoDifference(jsValue.invokeMethod("has", withArguments: [20]).toBool(), true)
    expectNoDifference(jsValue.invokeMethod("has", withArguments: [30]).toBool(), true)
    expectNoDifference(jsValue.invokeMethod("has", withArguments: [40]).toBool(), false)

    expectNoDifference(try Set<Int>(jsValue: jsValue), values)
  }

  @Test("RawRepresentable Conversion")
  func rawRepresentableConversion() throws {
    struct SomeValue: Hashable, RawRepresentable, JSValueConvertible {
      let rawValue: Int
    }

    let context = JSContext()!

    let someValue = SomeValue(rawValue: 42)
    let jsValue = someValue.jsValue(in: context)

    expectNoDifference(jsValue.isNumber, true)
    expectNoDifference(jsValue.toInt32(), 42)

    expectNoDifference(try SomeValue(jsValue: jsValue), someValue)
  }

  @Test("Optional Conversion")
  func optionalConversion() throws {
    let context = JSContext()!

    let someValue: Int? = 42
    let jsValue = someValue.jsValue(in: context)

    expectNoDifference(jsValue.isNumber, true)
    expectNoDifference(jsValue.toInt32(), 42)

    expectNoDifference(try Int?(jsValue: jsValue), someValue)
    expectNoDifference(try Int?(jsValue: JSValue(undefinedIn: context)), nil)
    expectNoDifference(try Int?(jsValue: JSValue(nullIn: context)), nil)
  }
}
