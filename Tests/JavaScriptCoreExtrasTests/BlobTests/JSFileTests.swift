import CustomDump
@preconcurrency import JavaScriptCoreExtras
import Testing

@Suite("JSFile tests")
struct JSFileTests {
  private let context = JSContext()!

  init() throws {
    try self.context.install([.consoleLogging, .fetch])
  }

  @Test(
    "Cannot Construct from a Non-Iterable Value",
    arguments: [
      """
      new File("", "foo.txt")
      """,
      """
      new File(true, "foo.txt")
      """,
      """
      new File(1, "foo.txt")
      """,
      """
      new File({ foo: "bar", a: 2 }, "foo.txt")
      """,
      """
      class C {}
      new File(new C(), "foo.txt")
      """
    ]
  )
  func nonIterable(initObject: String) {
    expectErrorMessage(
      js: initObject,
      message:
        "Failed to construct 'File': The provided value cannot be converted to a sequence.",
      in: self.context
    )
  }

  @Test("Cannot Construct Without Name")
  func noName() {
    expectErrorMessage(
      js: "new File([])",
      message: "Failed to construct 'File': 2 arguments required, but only 1 present.",
      in: self.context
    )
  }

  @Test("Cannot Construct Without Contents")
  func noContents() {
    expectErrorMessage(
      js: "new File()",
      message: "Failed to construct 'File': 2 arguments required, but only 0 present.",
      in: self.context
    )
  }

  @Test("Cannot Construct With Invalid Options")
  func invalidOptions() {
    expectErrorMessage(
      js: "new File([\"foo\"], \"foo.txt\", \"f\")",
      message: "Failed to construct 'File': The provided value is not of type 'FilePropertyBag'.",
      in: self.context
    )
  }

  @Test("Construct With Last Modified", arguments: ["new Date(10)", "10"])
  func lastModified(initObject: String) async {
    let value = self.context.evaluateScript(
      "new File([], \"test.txt\", { lastModified: \(initObject) })"
    )
    expectNoDifference(value?.objectForKeyedSubscript("lastModified").toInt32(), 10)
  }

  @Test("Construct With Numeric Name")
  func numericName() async {
    let value = self.context.evaluateScript(
      """
      new File([], 1, { type: "application/json" }).name
      """
    )
    expectNoDifference(value?.toString(), "1")
  }

  @Test(
    "Text",
    arguments: [
      ("new File(new Blob([\"foo\"]), \"foo.txt\")", "foo"),
      ("new File([], \"foo.txt\")", ""),
      ("new File([\"foo\"], \"foo.txt\")", "foo"),
      ("new File([\"foo\", \"bar\"], \"foo.txt\")", "foobar"),
      ("new File(new Uint8Array(10), \"foo.txt\")", "0000000000"),
      (
        "new File(new Headers([[\"Key\", \"Value\"], [\"K\", \"V\"]]), \"foo.txt\")",
        "key,Valuek,V"
      ),
      (
        "new File([JSON.stringify({ a: \"Test\", b: 42 })], \"test.txt\")",
        "{\"a\":\"Test\",\"b\":42}"
      )
    ]
  )
  func textFromIterable(initObject: String, expected: String) async throws {
    let value = try await #require(
      self.context.evaluateScript("\(initObject).text()").toPromise()
    )
    .resolvedValue
    expectNoDifference(value.toString(), expected)
  }

  @Test("File exists")
  func exists() {
    let value = self.context.objectForKeyedSubscript("File")
    expectNoDifference(value?.isUndefined, false)
  }

  @Test("Instance of Blob")
  func instanceOfBlob() {
    let value = self.context.evaluateScript(
      """
      new File([], "foo.txt") instanceof Blob
      """
    )
    expectNoDifference(value?.toBool(), true)
  }

  #if canImport(UniformTypeIdentifiers)
    @Test("From URL")
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func fromURL() async throws {
      let name = "\(UUID()).json"
      let temp = URL.temporaryDirectory.appending(path: name)
      try "{ \"key\": true }".write(to: temp, atomically: true, encoding: .utf8)
      let file = try JSFile(contentsOf: temp)
      self.context.setObject(file, forPath: "testFile")
      let value = try await #require(
        self.context.evaluateScript("testFile.text().then((t) => JSON.parse(t))").toPromise()
      )
      .resolvedValue
      expectNoDifference(file.name, name)
      expectNoDifference(file.size, 15)
      expectNoDifference(file.type, "application/json")
      expectNoDifference(value.objectForKeyedSubscript("key").toBool(), true)
    }

    @Test("Sliced From URL")
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func slicedFromURL() async throws {
      let temp = URL.temporaryDirectory.appending(path: "\(UUID()).json")
      try "Hello world".write(to: temp, atomically: true, encoding: .utf8)
      let file = try JSFile(contentsOf: temp)
      self.context.setObject(file, forPath: "testFile")
      let value = try await #require(
        self.context.evaluateScript("testFile.slice(0, 5).text()").toPromise()
      )
      .resolvedValue
      expectNoDifference(value.toString(), "Hello")
    }

    @Test("From Non-Existent URL During Read")
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func nonExistentURL() async throws {
      let temp = URL.temporaryDirectory.appending(path: "\(UUID()).json")
      try "Hello world".write(to: temp, atomically: true, encoding: .utf8)
      let file = try JSFile(contentsOf: temp)
      try FileManager.default.removeItem(at: temp)
      self.context.setObject(file, forPath: "testFile")
      let value = try #require(self.context.evaluateScript("testFile.text()").toPromise())
      await #expect(throws: Error.self) { try await value.resolvedValue }
    }
  #endif
}
