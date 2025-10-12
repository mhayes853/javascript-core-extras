import CoreGraphics
import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("CoreGraphics+JSValueConvertible tests")
struct CoreGraphicsJSValueConvertibleTests {
  @Test(
    "JSValue Is Rect",
    arguments: [
      ({ @Sendable c in JSValue(newObjectIn: c) }, false),
      ({ @Sendable c in JSValue(bool: true, in: c) }, false),
      ({ @Sendable c in JSValue(rect: CGRect(origin: .zero, size: .zero), in: c) }, true),
      (
        { @Sendable c in
          let object = JSValue(newObjectIn: c)!
          object.setValue(0, forPath: "x")
          object.setValue(10, forPath: "y")
          object.setValue(43, forPath: "width")
          object.setValue(50, forPath: "height")
          return object
        },
        true
      )
    ]
  )
  func jsValueIsRect(value: @Sendable (JSContext) -> JSValue, isRect: Bool) {
    let context = JSContext()!
    let value = value(context)
    expectNoDifference(value.isRect, isRect)
  }

  @Test("Converts Rect")
  func convertsRect() throws {
    let context = JSContext()!
    let rect = CGRect(x: 0, y: 10, width: 43, height: 50)
    let jsValue = rect.jsValue(in: context)

    expectNoDifference(jsValue.isObject, true)
    expectNoDifference(jsValue.isRect, true)
    expectNoDifference(jsValue.objectForKeyedSubscript("x").toInt32(), 0)
    expectNoDifference(jsValue.objectForKeyedSubscript("y").toInt32(), 10)
    expectNoDifference(jsValue.objectForKeyedSubscript("width").toInt32(), 43)
    expectNoDifference(jsValue.objectForKeyedSubscript("height").toInt32(), 50)

    expectNoDifference(try CGRect(jsValue: jsValue), rect)
  }

  @Test(
    "JSValue Is Size",
    arguments: [
      ({ @Sendable c in JSValue(newObjectIn: c) }, false),
      ({ @Sendable c in JSValue(bool: true, in: c) }, false),
      ({ @Sendable c in JSValue(rect: CGRect(origin: .zero, size: .zero), in: c) }, true),
      (
        { @Sendable c in
          let object = JSValue(newObjectIn: c)!
          object.setValue(43, forPath: "width")
          object.setValue(50, forPath: "height")
          return object
        },
        true
      ),
      ({ @Sendable c in JSValue(size: CGSize(width: 43, height: 50), in: c) }, true)
    ]
  )
  func jsValueIsSize(value: @Sendable (JSContext) -> JSValue, isSize: Bool) {
    let context = JSContext()!
    let value = value(context)
    expectNoDifference(value.isSize, isSize)
  }

  @Test("Converts Size")
  func convertsSzie() throws {
    let context = JSContext()!
    let rect = CGSize(width: 43, height: 50)
    let jsValue = rect.jsValue(in: context)

    expectNoDifference(jsValue.isObject, true)
    expectNoDifference(jsValue.isSize, true)
    expectNoDifference(jsValue.objectForKeyedSubscript("width").toInt32(), 43)
    expectNoDifference(jsValue.objectForKeyedSubscript("height").toInt32(), 50)

    expectNoDifference(try CGSize(jsValue: jsValue), rect)
  }
}
