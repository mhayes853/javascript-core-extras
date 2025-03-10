import CustomDump
import IssueReporting
import JavaScriptCoreExtras
import Testing

@Suite("JSRequest tests")
struct JSRequestTests {
  private let context = JSContext()!

  init() throws {
    try self.context.install([.consoleLogging, .request])
  }

  @Test("Construct With Non-Object RequestInit")
  func nonObjectRequestInit() {
    expectErrorMessage(
      js: """
        new Request("https://www.example.com", "")
        """,
      message: "Failed to construct 'Request': The provided value is not of type 'RequestInit'.",
      in: self.context
    )
  }

  @Test("Makes Shallow Copy of Request Init")
  func shallowCopiesInit() {
    let value = self.context.evaluateScript(
      """
      const init = { method: "POST" }
      const req = new Request("https://www.example.com", init)
      init.method = "PATCH"
      req.method
      """
    )
    expectNoDifference(value?.toString(), "POST")
  }

  @Test("URL")
  func url() {
    let value = self.context.evaluateScript(
      """
      new Request("https://www.example.com").url
      """
    )
    expectNoDifference(value?.toString(), "https://www.example.com")
  }

  @Test("Method is GET by Default")
  func defaultMethod() {
    let value = self.context.evaluateScript(
      """
      new Request("https://www.example.com").method
      """
    )
    expectNoDifference(value?.toString(), "GET")
  }

  @Test("Method")
  func method() {
    let value = self.context.evaluateScript(
      """
      new Request("https://www.example.com", { method: "POST" }).method
      """
    )
    expectNoDifference(value?.toString(), "POST")
  }

  @Test("Numeric Method")
  func numericMethod() {
    let value = self.context.evaluateScript(
      """
      new Request("https://www.example.com", { method: 1 }).method
      """
    )
    expectNoDifference(value?.toString(), "1")
  }

  @Test("Empty Headers")
  func emptyHeaders() {
    let value = self.context.evaluateScript(
      """
      Array.from(new Request("https://www.example.com", { method: 1 }).headers)
      """
    )
    expectNoDifference(value?.toArray().count, 0)
  }

  @Test(
    "Valid Headers",
    arguments: [
      """
      new Headers([["key", "value"], ["foo", "bar"]])
      """,
      """
      [["key", "value"], ["foo", "bar"]]
      """,
      """
      { key: "value", foo: "bar" }
      """
    ]
  )
  func validHeaders(initObject: String) {
    let value = self.context.evaluateScript(
      """
      Array.from(
        new Request("https://www.example.com", { headers: \(initObject) }).headers
      )
      """
    )
    expectHeaders(from: value, toEqual: [["key", "value"], ["foo", "bar"]])
  }

  @Test("Invalid Headers Init Throws Error")
  func invalidHeader() {
    expectErrorMessage(
      js: """
        new Request("https://www.example.com", { method: 1, headers: "" }).headers
        """,
      message:
        "Failed to construct 'Request': Failed to read the 'headers' property from 'RequestInit': The provided value is not of type '(record<ByteString, ByteString> or sequence<sequence<ByteString>>)'.",
      in: self.context
    )
  }

  @Test(
    "Keep Alive",
    arguments: [("", false), (true, true), (false, false), ("\"jkhskjhs\"", true)]
      as [(any Sendable, Bool)]
  )
  func keepAlive(initObject: any Sendable, expected: Bool) {
    let value = self.context.evaluateScript(
      """
      new Request("https://www.example.com", { keepalive: \(initObject) }).keepalive
      """
    )
    expectNoDifference(value?.toBool(), expected)
  }

  @Test("Body Text")
  func bodyText() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", { method: "POST", body: "foo" }).text()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toString(), "foo")
  }

  @Test("Body Bytes")
  func bodyBytes() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", { method: "POST", body: "foo" }).bytes()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toArray().compactMap { $0 as? UInt8 }, [0x66, 0x6F, 0x6F])
  }

  @Test("Blob Body Bytes")
  func blobBodyBytes() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", {
          method: "POST",
          body: new Blob(["foo"])
        })
        .bytes()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toArray().compactMap { $0 as? UInt8 }, [0x66, 0x6F, 0x6F])
  }

  @Test("Uint8Array Body Bytes")
  func uint8ArrayBodyBytes() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", {
          method: "POST",
          body: new Uint8Array([0x66, 0x6F, 0x6F])
        })
        .bytes()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toArray().compactMap { $0 as? UInt8 }, [0x66, 0x6F, 0x6F])
  }

  @Test("Uint16Array Body Bytes")
  func uint16ArrayBodyBytes() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", {
          method: "POST",
          body: new Uint16Array([0x66, 0x6F, 0x6F])
        })
        .bytes()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(
      resolved?.toArray().compactMap { $0 as? UInt8 },
      [0x66, 0x00, 0x6F, 0x00, 0x6F, 0x00]
    )
  }

  @Test(
    "Cannot Have Body for GET or HEAD Request",
    arguments: ["\"GET\"", "\"HEAD\"", "undefined"]
  )
  func noBodyAllowed(method: String) async throws {
    expectErrorMessage(
      js: """
        new Request("https://www.example.com", { method: \(method), body: "foo" })
        """,
      message: "Failed to construct 'Request': Request with GET/HEAD method cannot have body.",
      in: self.context
    )
  }

  @Test("Stringifies Non-Iterable Body")
  func stringifiesBody() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", { method: "POST", body: {} }).text()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toString(), "[object Object]")
  }

  @Test("Empty Body Text")
  func emptyBodyText() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com").text()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toString(), "")
  }

  @Test("Empty Body Bytes")
  func emptyBodyBytes() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com").bytes()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toArray().compactMap { $0 as? UInt8 }, [])
  }

  @Test("Uint8Array Body Text")
  func uint8ArrayBodyText() async throws {
    let value = self.context
      .evaluateScript(
        """
        const array = new Uint8Array([0x66, 0x6F, 0x6F])
        new Request("https://www.example.com", { method: "POST", body: array }).text()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toString(), "foo")
  }

  @Test("Uint16Array Body Text")
  func uint16ArrayBodyText() async throws {
    let value = self.context
      .evaluateScript(
        """
        const array = new Uint16Array([0x66, 0x6F, 0x6F])
        new Request("https://www.example.com", { method: "POST", body: array }).text()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.toString(), "f\0o\0o\0")
  }

  @Test(
    "Body Blob",
    arguments: [
      ("'string'", "string"),
      ("new Uint8Array([0x66, 0x6F, 0x6F])", "foo"),
      ("new Blob(['foo'])", "foo"),
      ("undefined", "")
    ]
  )
  func bodyBlob(initObject: String, string: String) async throws {
    let value = self.context
      .evaluateScript(
        """
        const load = async () => {
          const b = await new Request("https://www.example.com", {
            method: "POST",
            body: \(initObject)
          })
          .blob()
          return { text: await b.text(), isBlob: b instanceof Blob }
        }
        load()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.objectForKeyedSubscript("text").toString(), string)
    expectNoDifference(resolved?.objectForKeyedSubscript("isBlob").toBool(), true)
  }

  @Test("Body JSON")
  func bodyJSON() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", {
          method: "POST",
          body: JSON.stringify({ a: "b" })
        })
        .json()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.objectForKeyedSubscript("a").toString(), "b")
  }

  @Test("Blob Body JSON")
  func blobBodyJSON() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", {
          method: "POST",
          body: new Blob([JSON.stringify({ a: "b" })])
        })
        .json()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(resolved?.objectForKeyedSubscript("a").toString(), "b")
  }

  @Test("Invalid JSON")
  func invalidJSON() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Request("https://www.example.com", { method: "POST", body: "foo" }).json()
        """
      )
      .toPromise()
    do {
      try await value?.resolvedValue
      reportIssue("Should reject")
    } catch {
      let error = try #require(error as? JSPromiseRejectedError)
      expectNoDifference(
        error.reason.objectForKeyedSubscript("message")?.toString(),
        #"JSON Parse error: Unexpected identifier "foo""#
      )
    }
  }

  @Test("Body Not Used When Created")
  func bodyNotUsed() {
    let value = self.context.evaluateScript(
      """
      new Request("www.example.com", { method: "POST", body: "foo" }).bodyUsed
      """
    )
    expectNoDifference(value?.toBool(), false)
  }

  @Test(
    "Body Used After Consuming",
    arguments: ["text", "bytes", "blob", "arrayBuffer", "json", "formData"]
  )
  func bodyUsed(methodName: String) async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const request = new Request("www.example.com", { method: "POST", body: "foo" })
          try {
            await request.\(methodName)()
          } catch {}
          return request.bodyUsed
        }
        run()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(resolvedValue?.toBool(), true)
  }

  @Test(
    "Throws Error When Consuming Body a Second Time",
    arguments: ["text", "bytes", "blob", "arrayBuffer", "json", "formData"]
  )
  func consumeBodyTwice(methodName: String) async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const request = new Request("www.example.com", { method: "POST", body: "foo" })
          try {
            await request.\(methodName)()
          } catch {}
          try {
            await request.\(methodName)()
          } catch (e) {
            return e.message
          }
        }
        run()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(
      resolvedValue?.toString(),
      "Failed to execute '\(methodName)' on 'Request': body stream already read"
    )
  }

  @Test(
    "Request Cloning Allows Second Consumption of Body",
    arguments: ["text", "bytes", "blob", "arrayBuffer", "json", "formData"]
  )
  func cloneConsumeBodyTwice(methodName: String) async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const request = new Request("www.example.com", { method: "POST", body: "foo" })
          const request2 = request.clone()
          try {
            await request.\(methodName)()
          } catch {}
          try {
            await request2.\(methodName)()
            return true
          } catch (e) {
            return !e.message.includes("body stream already read")
          }
        }
        run()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(resolvedValue?.toBool(), true)
  }

  @Test(
    "Cloning Consumed Request Carries Over Body Consumption Status",
    arguments: ["text", "bytes", "blob", "arrayBuffer", "json", "formData"]
  )
  func carriesBodyConsumptionStatus(methodName: String) async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const request = new Request("www.example.com", { method: "POST", body: "foo" })
          try {
            await request.\(methodName)()
          } catch {}
          const request2 = request.clone()
          try {
            await request2.\(methodName)()
          } catch (e) {
            return e.message
          }
        }
        run()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(
      resolvedValue?.toString(),
      "Failed to execute '\(methodName)' on 'Request': body stream already read"
    )
  }

  @Test("Fails to Construct FormData Body if Body is Not FormData")
  func failsFormDataBody() async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const request = new Request("www.example.com", { method: "POST", body: "foo" })
          try {
            await request.formData()
            return true
          } catch (e) {
            return e.message
          }
        }
        run()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(
      resolvedValue?.toString(),
      "Failed to execute 'formData' on 'Request': Failed to fetch"
    )
  }

  @Test("Returns Form Data Body")
  func formDataBody() async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const formData = new FormData()
          formData.set("foo", "bar")
          const request = new Request("www.example.com", { method: "POST", body: formData })
          formData.set("a", "b")
          const formData2 = await request.formData()
          return { isSame: formData === formData2, foo: formData2.get("foo"), a: formData2.get("a") }
        }
        run()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(resolvedValue?.objectForKeyedSubscript("isSame").toBool(), false)
    expectNoDifference(resolvedValue?.objectForKeyedSubscript("foo").toString(), "bar")
    expectNoDifference(resolvedValue?.objectForKeyedSubscript("a").isNull, true)
  }

  @Test("Request Clone Copies FormData")
  func copiesFormDataOnClone() async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const request = new Request("www.example.com", { method: "POST", body: new FormData() })
          const request2 = request.clone()
          const formData = await request.formData()
          formData.set("a", "b")
          const formData2 = await request2.formData()
          return { isSame: formData === formData2, a: formData2.get("a") }
        }
        run()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(resolvedValue?.objectForKeyedSubscript("isSame").toBool(), false)
    expectNoDifference(resolvedValue?.objectForKeyedSubscript("a").isNull, true)
  }

  #if canImport(UniformTypeIdentifiers)
    @Test(
      "FormData Body Text",
      arguments: [
        "request.text()",
        "request.blob().then((b) => b.text())",
        "request.bytes().then((b) => _jsCoreExtrasUint8ArrayToString(b))"
      ]
    )
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func formDataBodyText(text: String) async throws {
      let url = URL.temporaryDirectory.appending(path: "\(UUID()).txt")
      try "Hello world".write(to: url, atomically: true, encoding: .utf8)
      let file = try JSFile(contentsOf: url)
      self.context.setObject(file, forPath: "testFile")
      let value = self.context
        .evaluateScript(
          """
          function _jsCoreExtrasFormDataBoundary() {
            return "-----testBoundary"
          }

          const formData = new FormData()
          formData.set("file", testFile)
          formData.append("a", "b")
          formData.append("a", "c")
          const request = new Request("www.example.com", { method: "POST", body: formData })
          \(text)
          """
        )
        .toPromise()
      let resolvedValue = try await value?.resolvedValue
      expectNoDifference(
        resolvedValue?.toString(),
        """
        -----testBoundary\r\nContent-Disposition: form-data; name="file"; filename="\(file.name)"\r\nContent-Type: text/plain\r\n\r\nHello world\r\n-----testBoundary\r\nContent-Disposition: form-data; name="a"\r\n\r\nb\r\n-----testBoundary\r\nContent-Disposition: form-data; name="a"\r\n\r\nc\r\n-----testBoundary--\r\n
        """
      )
    }
  #endif

  @Test("Sets Content-Type Header to multipart/form-data When Body is FormData")
  func multipartFormData() {
    let value = self.context
      .evaluateScript(
        """
        function _jsCoreExtrasFormDataBoundary() {
          return "-----testBoundary"
        }
        new Request("www.example.com", {
          method: "POST",
          body: new FormData()
        })
        .headers
        .get("content-type")
        """
      )
    expectNoDifference(value?.toString(), "multipart/form-data; boundary=-----testBoundary")
  }

  @Test(
    "Keeps Content-Type Header to Current Content-Type When Body is FormData But Content-Type Specified"
  )
  func keepsContentTypeHeader() {
    let value = self.context
      .evaluateScript(
        """
        function _jsCoreExtrasFormDataBoundary() {
          return "-----testBoundary"
        }
        new Request("www.example.com", {
          method: "POST",
          body: new FormData(),
          headers: { "Content-Type": "application/json" }
        })
        .headers
        .get("content-type")
        """
      )
    expectNoDifference(value?.toString(), "application/json")
  }

  @Test(
    "Sets Content-Type Header to text/plain When Body is String",
    arguments: ["\"\"", "new String()", "1"]
  )
  func textPlain(initObject: String) {
    let value = self.context
      .evaluateScript(
        """
        new Request("www.example.com", {
          method: "POST",
          body: ""
        })
        .headers
        .get("content-type")
        """
      )
    expectNoDifference(value?.toString(), "text/plain; charset=UTF-8")
  }

  @Test("Sets Content-Type Header to Blob type When Body is Blob")
  func blobContentType() {
    let value = self.context
      .evaluateScript(
        """
        new Request("www.example.com", {
          method: "POST",
          body: new Blob([], { type: "application/json" })
        })
        .headers
        .get("content-type")
        """
      )
    expectNoDifference(value?.toString(), "application/json")
  }

  @Test("Request Clone Overrides Previous Request Options")
  func requestCloneOptionsOverride() async throws {
    let value = self.context
      .evaluateScript(
        """
        const request = new Request("www.example.com", { method: "POST", cache: "reload" })
        new Request(request, { method: "GET", keepalive: true })
        """
      )
    expectNoDifference(value?.objectForKeyedSubscript("method").toString(), "GET")
    expectNoDifference(value?.objectForKeyedSubscript("keepalive").toBool(), true)
    expectNoDifference(
      value?.objectForKeyedSubscript("url").toString(),
      "www.example.com"
    )
    expectNoDifference(value?.objectForKeyedSubscript("cache").toString(), "reload")
  }

  @Test("Request Clone Overrides Previous Request Body")
  func requestCloneBodyOverride() async throws {
    let value = self.context
      .evaluateScript(
        """
        const request = new Request("www.example.com", { method: "POST", body: "foo" })
        new Request(request, { body: "bar" }).text()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(resolvedValue?.toString(), "bar")
  }
}
