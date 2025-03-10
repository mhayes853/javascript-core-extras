import JavaScriptCoreExtras
import Testing

@Suite("JSContext+SetObject tests")
struct JSContextSetObjectTests {
  private let context = JSContext()!

  @Test("Set the same global property multiple times, overrides value")
  func setGlobal() {
    self.context.setObject("hello", forPath: "str")
    self.context.setObject("world", forPath: "str")
    let value = self.context.evaluateScript("str")
    #expect(value?.toString() == "world")
  }

  @Test("Set different global property multiple times, overrides value")
  func setDifferentGlobal() {
    self.context.setObject("hello", forPath: "str")
    self.context.setObject("world", forPath: "str2")
    var value = self.context.evaluateScript("str")
    #expect(value?.toString() == "hello")

    value = self.context.evaluateScript("str2")
    #expect(value?.toString() == "world")
  }

  @Test("Set the same nested property multiple times, overrides value")
  func setNested() {
    self.context.setObject("hello", forPath: "str.foo")
    self.context.setObject("world", forPath: "str.foo")
    let value = self.context.evaluateScript("str.foo")
    #expect(value?.toString() == "world")
  }

  @Test("Set super nested property, sets value")
  func setSuperNested() {
    self.context.setObject("hello", forPath: "str.foo.bar.baz.z")
    let value = self.context.evaluateScript("str.foo.bar.baz.z")
    #expect(value?.toString() == "hello")
  }

  @Test("Set different properties on nested object, sets values for properties")
  func setDifferentNested() {
    self.context.setObject("hello", forPath: "str.foo")
    self.context.setObject("world", forPath: "str.bar")
    var value = self.context.evaluateScript("str.foo")
    #expect(value?.toString() == "hello")

    value = self.context.evaluateScript("str.bar")
    #expect(value?.toString() == "world")
  }

  @Test("Set with empty string, nothing occurs")
  func setEmpty() {
    self.context.setObject("hello", forPath: "")
    let value = self.context.evaluateScript("")
    #expect(value?.isUndefined == true)
  }

  @Test("Set with invalid string, nothing occurs")
  func setInvalid() {
    self.context.setObject("hello", forPath: "2897298")
    let value = self.context.evaluateScript("2897298")
    #expect(value?.toInt32() == 2_897_298)
  }

  @Test("Set property on a non-object, nothing occurs")
  func setNonObject() {
    self.context.setObject(5, forPath: "str")
    self.context.setObject("hello", forPath: "str.foo")
    var value = self.context.evaluateScript("str.foo")
    #expect(value?.isUndefined == true)

    value = self.context.evaluateScript("str")
    #expect(value?.toInt32() == 5)
  }
}
