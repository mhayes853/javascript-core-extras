import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("JSHeaders tests")
struct JSHeadersTests {
  private let context = JSContext()!

  init() throws {
    try self.context.install([.fetch, .consoleLogging])
  }

  @Test("Empty Headers Init Has Nothing")
  func empty() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers()
      Array.from(headers.entries())
      """
    )
    expectHeaders(from: value, toEqual: [])
  }

  @Test(
    "Construct from Initial Headers",
    arguments: [
      """
      const headers = new Headers({ 60: "Num", "Content-Type": "application/json", "Foo": ["bar", "baz", 1], Num: 60 })
      """,
      """
      const headers = new Headers([[60, "Num"], ["Content-Type", "application/json"], ["Foo", ["bar", "baz", 1]], ["Num", 60]])
      """,
      """
      const headers = new Headers(new Map([[60, "Num"], ["Content-Type", "application/json"], ["Foo", ["bar", "baz", 1]], ["Num", 60]]))
      """,
      """
      class X {
        60 = "Num"
        "Content-Type" = "application/json"
        Foo = ["bar", "baz", 1]
        Num = 60
      }
      const headers = new Headers(new X())
      """
    ]
  )
  func initialHeaders(initObject: String) {
    let value = self.context.evaluateScript(
      """
      \(initObject)
      Array.from(headers.entries())
      """
    )
    expectHeaders(
      from: value,
      toEqual: [
        ["60", "Num"], ["content-type", "application/json"], ["foo", "bar,baz,1"],
        ["num", "60"]
      ]
    )
  }

  @Test("Keys")
  func keys() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers({ 60: "Num", "Content-Type": "application/json", "Foo": ["bar", "baz", 1], Num: 60 })
      Array.from(headers.keys())
      """
    )
    expectNoDifference(
      value?.toArray().compactMap { $0 as? String },
      ["60", "content-type", "foo", "num"]
    )
  }

  @Test("Values")
  func values() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers({ 60: "Num", "Content-Type": "application/json", "Foo": ["bar", "baz", 1], Num: 60 })
      Array.from(headers.values())
      """
    )
    expectNoDifference(
      value?.toArray().compactMap { $0 as? String },
      ["Num", "application/json", "bar,baz,1", "60"]
    )
  }

  @Test("ForEach")
  func forEach() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers({ 60: "Num", "Content-Type": "application/json", "Foo": ["bar", "baz", 1], Num: 60 })
      const results = []
      headers.forEach((value) => results.push(value))
      results
      """
    )
    expectNoDifference(
      value?.toArray().compactMap { $0 as? String },
      ["Num", "application/json", "bar,baz,1", "60"]
    )
  }

  @Test("Has")
  func has() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers({ 60: "Num", "Content-Type": "application/json", "Foo": ["bar", "baz", 1], Num: 60 })
      const results = [headers.has("60"), headers.has("Content-Type"), headers.has(60), headers.has("skljlkdjlkd")]
      results
      """
    )
    expectNoDifference(
      value?.toArray().compactMap { $0 as? Bool },
      [true, true, true, false]
    )
  }

  @Test("Get")
  func get() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers({ 60: "Num", "Content-Type": "application/json", "Foo": ["bar", "baz", 1], Num: 60 })
      const results = [headers.get("60"), headers.get("Content-Type"), headers.get(60), headers.get("skljlkdjlkd")]
      results
      """
    )
    expectNoDifference(
      value?.toArray().map { $0 as? String },
      ["Num", "application/json", "Num", nil]
    )
  }

  @Test("Set")
  func set() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers({ "Content-Type": ["application/json", "blob"] })
      headers.set("Foo", "Bar")
      headers.set("A", ["B", "C"])
      headers.set(50, "bar")
      headers.set("B", 20)
      headers.set("Content-Type", "application/pdf")
      Array.from(headers)
      """
    )
    expectHeaders(
      from: value,
      toEqual: [
        ["content-type", "application/pdf"], ["foo", "Bar"], ["a", "B,C"], ["50", "bar"],
        ["b", "20"]
      ]
    )
  }

  @Test("Set and Get")
  func setAndGet() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers()
      headers.set("foo", "Bar")
      headers.get("Foo")
      """
    )
    expectNoDifference(value?.toString(), "Bar")
  }

  @Test("Get Set Cookie")
  func getSetCookie() {
    let value = self.context.evaluateScript(
      """
      const results = []
      const headers = new Headers()
      results.push(headers.getSetCookie())
      headers.set("set-cookie", "blob1=blib2")
      results.push(headers.getSetCookie())
      headers.set("Set-Cookie", "")
      headers.append("Set-Cookie", "")
      results.push(headers.getSetCookie())
      headers.set("Set-Cookie", "name1=value1")
      headers.append("set-Cookie", "name2=value2")
      results.push(headers.getSetCookie())
      results
      """
    )
    expectNoDifference(
      value?.toArray().map { $0 as? [String] },
      [[], ["blob1=blib2"], ["", ""], ["name1=value1", "name2=value2"]]
    )
  }

  @Test("Delete")
  func delete() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers()
      headers.set(2, "Bar")
      headers.delete("2")
      headers.get(2)
      """
    )
    #expect(value?.isNull == true)
  }

  @Test("Append")
  func append() {
    let value = self.context.evaluateScript(
      """
      const headers = new Headers({ Foo: "A" })
      headers.append("Foo", ["B", "C"])
      headers.append(2, "Bar")
      headers.append(2, "Baz")
      const results = [headers.get(2), headers.get("Foo")]
      results
      """
    )
    expectNoDifference(
      value?.toArray().map { $0 as? String },
      ["Bar, Baz", "A, B,C"]
    )
  }

  @Test(
    "Invalid Constructions",
    arguments: [
      """
      new Headers("foo", "bar")
      """,
      """
      new Headers("foo")
      """,
      """
      new Headers(1, 2, 3, 4)
      """
    ]
  )
  func invalidConstructions(initObject: String) async {
    await confirmation { confirm in
      self.context.exceptionHandler = { _, value in
        let message = value?.objectForKeyedSubscript("message")?.toString()
        expectNoDifference(
          message,
          "Failed to construct 'Headers': The provided value is not of type '(record<ByteString, ByteString> or sequence<sequence<ByteString>>)'."
        )
        confirm()
      }
      self.context.evaluateScript(initObject)
    }
  }

  @Test(
    "Unsequenceable Constructions",
    arguments: [
      """
      new Headers(["foo", "bar"])
      """
    ]
  )
  func unsequenceableConstructions(initObject: String) async {
    await confirmation { confirm in
      self.context.exceptionHandler = { _, value in
        let message = value?.objectForKeyedSubscript("message")?.toString()
        expectNoDifference(
          message,
          "Failed to construct 'Headers': The provided value cannot be converted to a sequence."
        )
        confirm()
      }
      self.context.evaluateScript(initObject)
    }
  }

  @Test(
    "Invalid Value",
    arguments: [
      """
      new Headers([["foo", "bar", "baz"]])
      """,
      """
      new Headers([["foo"]])
      """
    ]
  )
  func invalidValueConstructions(initObject: String) async {
    await confirmation { confirm in
      self.context.exceptionHandler = { _, value in
        let message = value?.objectForKeyedSubscript("message")?.toString()
        expectNoDifference(
          message,
          "Failed to construct 'Headers': Invalid value."
        )
        confirm()
      }
      self.context.evaluateScript(initObject)
    }
  }
}
