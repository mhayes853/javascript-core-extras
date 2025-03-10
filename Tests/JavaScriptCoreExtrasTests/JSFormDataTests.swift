import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("JSFormData tests")
struct JSFormDataTests {
  private let context = JSContext()!

  init() throws {
    try self.context.install([.formData, .consoleLogging])
  }

  @Test("Get Returns Null When No Value For Key")
  func getNull() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.get("foo")
      """
    )
    expectNoDifference(value?.isNull, true)
  }

  @Test("Get All Returns Empty When No Value For Key")
  func getAllEmpty() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.getAll("foo")
      """
    )
    expectNoDifference(value?.toArray().isEmpty, true)
  }

  @Test("Append and Get")
  func appendAndGet() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", "bar")
      data.append("foo", "baz")
      data.get("foo")
      """
    )
    expectNoDifference(value?.toString(), "bar")
  }

  @Test("Append and Get Numeric")
  func appendAndGetNumeric() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append(1, "bar")
      data.append(1, "baz")
      data.get(1)
      """
    )
    expectNoDifference(value?.toString(), "bar")
  }

  @Test("Set and Get Numeric")
  func setAndGetNumeric() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.set(1, "bar")
      data.get(1)
      """
    )
    expectNoDifference(value?.toString(), "bar")
  }

  @Test("Has")
  func has() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", "bar")
      data.set("bar", "baz")
      const results = [data.has("foo"), data.has("bar"), data.has("baz")]
      results
      """
    )
    expectNoDifference(value?.toArray().map { $0 as? Bool }, [true, true, false])
  }

  @Test("Delete and Get")
  func deleteAndGet() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", "bar")
      data.delete("foo")
      data.get("foo")
      """
    )
    expectNoDifference(value?.isNull, true)
  }

  @Test("Set and Get All")
  func setAndGetAll() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", "bar")
      data.append("foo", "baz")
      data.set("foo", true)
      data.getAll("foo")
      """
    )
    expectNoDifference(value?.toArray().map { $0 as? String }, ["true"])
  }

  @Test("Get All Returns All Values For a Key")
  func getAllValues() {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", 1)
      data.append("foo", "value")
      data.append("foo", ["bar", "baz"])
      data.getAll("foo")
      """
    )
    expectNoDifference(value?.toArray().compactMap { $0 as? String }, ["1", "value", "bar,baz"])
  }

  @Test("Set and Append Blob, Returns File with Empty Name")
  func blobWithEmptyFileName() async throws {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", new Blob(["test"]))
      data.set("bar", new Blob(["test"]))
      const results = [data.get("foo"), data.get("bar")]
      results
      """
    )
    let (v1, v2) = (value!.atIndex(0)!, value!.atIndex(1)!)
    expectNoDifference(
      [FileCompare(value: v1), FileCompare(value: v2)],
      [FileCompare(isFile: true, name: "blob"), FileCompare(isFile: true, name: "blob")]
    )
  }

  @Test("Set and Append Blob, Returns File With Specified Name")
  func blobWithFileName() async throws {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", new Blob(["test"]), "a.txt")
      data.set("bar", new Blob(["test"]), "b.txt")
      const results = [data.get("foo"), data.get("bar")]
      results
      """
    )
    let (v1, v2) = (value!.atIndex(0)!, value!.atIndex(1)!)
    expectNoDifference(
      [FileCompare(value: v1), FileCompare(value: v2)],
      [FileCompare(isFile: true, name: "a.txt"), FileCompare(isFile: true, name: "b.txt")]
    )
  }

  @Test("Set and Append File, Returns File with Original File Name")
  func fileWithEmptyFileName() async throws {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", new File(["test"], "test.txt"))
      data.set("bar", new File(["test"], "test.txt"))
      const results = [data.get("foo"), data.get("bar")]
      results
      """
    )
    let (v1, v2) = (value!.atIndex(0)!, value!.atIndex(1)!)
    expectNoDifference(
      [FileCompare(value: v1), FileCompare(value: v2)],
      [FileCompare(isFile: true, name: "test.txt"), FileCompare(isFile: true, name: "test.txt")]
    )
  }

  @Test("Set and Append File, Returns File With Specified Name")
  func fileWithFileName() async throws {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", new File(["test"], "test.txt"), "a.txt")
      data.set("bar", new File(["test"], "test.txt"), "b.txt")
      const results = [data.get("foo"), data.get("bar")]
      results
      """
    )
    let (v1, v2) = (value!.atIndex(0)!, value!.atIndex(1)!)
    expectNoDifference(
      [FileCompare(value: v1), FileCompare(value: v2)],
      [FileCompare(isFile: true, name: "a.txt"), FileCompare(isFile: true, name: "b.txt")]
    )
  }

  @Test("Keys")
  func keys() async throws {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", new File(["test"], "test.txt"), "a.txt")
      data.append("foo", "value")
      data.set("bar", "test")
      Array.from(data.keys())
      """
    )
    expectNoDifference(value?.toArray().map { $0 as? String }, ["foo", "foo", "bar"])
  }

  @Test("Values")
  func values() async throws {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", new File(["test"], "test.txt"), "a.txt")
      data.append("foo", "value")
      data.set("bar", "test")
      Array.from(data.values())
      """
    )
    let (v1, v2, v3) = (value!.atIndex(0)!, value!.atIndex(1)!, value!.atIndex(2)!)
    expectNoDifference(FileCompare(value: v1), FileCompare(isFile: true, name: "a.txt"))
    expectNoDifference(v2.toString(), "value")
    expectNoDifference(v3.toString(), "test")
  }

  @Test("Entries")
  func entries() async throws {
    let value = self.context.evaluateScript(
      """
      const data = new FormData()
      data.append("foo", new File(["test"], "test.txt"), "a.txt")
      data.append("foo", "value")
      data.set("bar", "test")
      Array.from(data)
      """
    )
    let (v1, v2, v3) = (value!.atIndex(0)!, value!.atIndex(1)!, value!.atIndex(2)!)
    expectNoDifference(v1.atIndex(0).toString(), "foo")
    expectNoDifference(
      FileCompare(value: v1.atIndex(1)!),
      FileCompare(isFile: true, name: "a.txt")
    )
    expectNoDifference(v2.toArray().map { $0 as? String }, ["foo", "value"])
    expectNoDifference(v3.toArray().map { $0 as? String }, ["bar", "test"])
  }

  @Test("For Each")
  func forEach() async throws {
    let value = self.context.evaluateScript(
      """
      const results = []
      const data = new FormData()
      data.append("foo", new File(["test"], "test.txt"), "a.txt")
      data.append("foo", "value")
      data.set("bar", "test")
      data.forEach((pair) => results.push(pair))
      results
      """
    )
    let (v1, v2, v3) = (value!.atIndex(0)!, value!.atIndex(1)!, value!.atIndex(2)!)
    expectNoDifference(FileCompare(value: v1), FileCompare(isFile: true, name: "a.txt"))
    expectNoDifference(v2.toString(), "value")
    expectNoDifference(v3.toString(), "test")
  }

  @Test("Cannot Set Filename on Non-Blob")
  func cannotSetFilenameNonBlob() async {
    await confirmation { confirm in
      self.context.exceptionHandler = { _, value in
        let message = value?.objectForKeyedSubscript("message")?.toString()
        expectNoDifference(
          message,
          "Failed to execute 'set' on 'FormData': parameter 2 is not of type 'Blob'."
        )
        confirm()
      }
      self.context.evaluateScript(
        """
        const data = new FormData()
        data.set("f", "f", "f")
        """
      )
    }
  }

  @Test("Cannot Append Filename on Non-Blob")
  func cannotAppendFilenameNonBlob() async {
    await confirmation { confirm in
      self.context.exceptionHandler = { _, value in
        let message = value?.objectForKeyedSubscript("message")?.toString()
        expectNoDifference(
          message,
          "Failed to execute 'append' on 'FormData': parameter 2 is not of type 'Blob'."
        )
        confirm()
      }
      self.context.evaluateScript(
        """
        const data = new FormData()
        data.append("f", "f", "f")
        """
      )
    }
  }
}

private struct FileCompare: Equatable {
  let isFile: Bool
  let name: String
}

extension FileCompare {
  init(value: JSValue) {
    let fileConstructor = value.context.objectForKeyedSubscript("File")
    self.isFile = value.isInstance(of: fileConstructor)
    self.name = value.objectForKeyedSubscript("name").toString()
  }
}
