import CustomDump
@preconcurrency import JavaScriptCoreExtras
import Testing

@Suite("JSBlob tests")
struct JSBlobTests {
  private let context = JSContext()!

  init() throws {
    try self.context.install([.fetch, .consoleLogging])
  }

  @Test(
    "Cannot Construct from a Non-Iterable Value",
    arguments: [
      """
      new Blob("")
      """,
      """
      new Blob(true)
      """,
      """
      new Blob(1)
      """,
      """
      new Blob({ foo: "bar", a: 2 })
      """,
      """
      class C {}
      new Blob(new C())
      """
    ]
  )
  func nonIterable(initObject: String) {
    expectErrorMessage(
      js: initObject,
      message:
        "Failed to construct 'Blob': The provided value cannot be converted to a sequence.",
      in: self.context
    )
  }

  @Test(
    "Text",
    arguments: [
      ("new Blob()", "")
      //("new Blob([])", ""),
      //("new Blob([\"foo\"])", "foo"),
      //("new Blob([\"foo\", \"bar\"])", "foobar"),
      //("new Blob(new Uint8Array(10))", "0000000000"),
      //("new Blob(new Headers([[\"Key\", \"Value\"], [\"K\", \"V\"]]))", "key,Valuek,V")
    ]
  )
  func textFromIterable(initObject: String, expected: String) async throws {
    let value = try await #require(
      self.context.evaluateScript("\(initObject).text()").toPromise()
    )
    .resolvedValue
    expectNoDifference(value.toString(), expected)
  }

  @Test(
    "Size",
    arguments: [
      ("new Blob()", 0),
      ("new Blob([])", 0),
      ("new Blob([\"foo\"])", 3),
      ("new Blob([\"foo\", \"bar\"])", 6),
      ("new Blob(new Uint8Array(10))", 10),
      ("new Blob(new Headers([[\"Key\", \"Value\"], [\"K\", \"V\"]]))", 12),
      ("new Blob([\"foo🔴\"])", 7)
    ]
  )
  func size(initObject: String, expected: Int32) {
    let value = self.context.evaluateScript("\(initObject).size")
    expectNoDifference(value?.toInt32(), expected)
  }

  @Test("Type")
  func type() {
    let value = self.context.evaluateScript("new Blob([], { type: \"application/json\" })")
    expectNoDifference(value?.objectForKeyedSubscript("type").toString(), "application/json")
  }

  @Test("Bytes")
  func bytes() async throws {
    let value = try await #require(
      self.context.evaluateScript("new Blob([\"foo\"]).bytes()").toPromise()
    )
    .resolvedValue
    .toArray()
    .compactMap { $0 as? UInt8 }
    expectNoDifference(value, [0x66, 0x6F, 0x6F])
  }

  @Test("Native Bytes")
  func nativeBytes() async throws {
    let blob = JSBlob(storage: "foo", type: .text)
    let utf8 = try await blob.utf8(context: self.context)
    expectNoDifference(String(utf8), "foo")
  }

  @Test("Array Buffer")
  func arrayBuffer() async throws {
    let value = try await #require(
      self.context
        .evaluateScript("new Blob([\"foo\"]).arrayBuffer().then((b) => new Uint8Array(b))")
        .toPromise()
    )
    .resolvedValue
    .toArray()
    .compactMap { $0 as? UInt8 }
    expectNoDifference(value, [0x66, 0x6F, 0x6F])
  }

  @Test("Slice")
  func slice() async throws {
    let value = try #require(
      self.context.evaluateScript(
        """
        const blob = new Blob(["foo", "bar"], { type: "application/xml" })
        const blobs = []
        blobs.push(blob.slice())
        blobs.push(blob.slice(1, 4))
        blobs.push(blob.slice(1))
        blobs.push(new Blob(["test"]).slice(-10, 400))
        blobs.push(new Blob(["test"]).slice("foo", "bar"))
        blobs.push(blob.slice(1, 4, "application/json").slice(1, 2))
        blobs
        """
      )
    )
    let blobs = try (0..<6).map { value.atIndex($0) }
      .map {
        (
          try #require($0!.objectForKeyedSubscript("type").toString()),
          try #require($0!.invokeMethod("text", withArguments: []).toPromise())
        )
      }
    expectNoDifference(
      blobs.map(\.0),
      ["application/xml", "application/xml", "application/xml", "", "", "application/json"]
    )
    try await withThrowingTaskGroup(of: JSValue.self) { group in
      for (_, promise) in blobs {
        group.addTask { try await promise.resolvedValue }
      }
      let values = try await group.reduce(into: [JSValue]()) { $0.append($1) }
        .map { $0.toString() }
      expectNoDifference(Set(values), ["foobar", "oob", "oobar", "test", "", "o"])
    }
  }
}
