import CustomDump
import IssueReporting
import JavaScriptCoreExtras
import Testing

@Suite("JSResponse tests")
struct JSResponseTests {
  private let context = JSContext()!

  init() throws {
    try self.context.install([.consoleLogging, .response])
  }

  @Test("Construct With Non-Object RequestInit")
  func nonObjectRequestInit() {
    expectErrorMessage(
      js: """
        new Response("foo", "")
        """,
      message:
        "Failed to construct 'Response': The provided value is not of type 'ResponseInit'.",
      in: self.context
    )
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
        new Response(undefined, { headers: \(initObject) }).headers
      )
      """
    )
    expectHeaders(from: value, toEqual: [["key", "value"], ["foo", "bar"]])
  }

  @Test("Invalid Headers Init Throws Error")
  func invalidHeader() {
    expectErrorMessage(
      js: """
        new Response("foo", { headers: "" }).headers
        """,
      message:
        "Failed to construct 'Response': Failed to read the 'headers' property from 'ResponseInit': The provided value is not of type '(record<ByteString, ByteString> or sequence<sequence<ByteString>>)'.",
      in: self.context
    )
  }

  @Test("Body Text")
  func bodyText() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Response("foo").text()
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
        new Response("foo").bytes()
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
        new Response(new Blob(["foo"])).bytes()
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
        new Response(new Uint8Array([0x66, 0x6F, 0x6F])).bytes()
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
        new Response(new Uint16Array([0x66, 0x6F, 0x6F])).bytes()
        """
      )
      .toPromise()
    let resolved = try await value?.resolvedValue
    expectNoDifference(
      resolved?.toArray().compactMap { $0 as? UInt8 },
      [0x66, 0x00, 0x6F, 0x00, 0x6F, 0x00]
    )
  }

  @Test("Stringifies Non-Iterable Body")
  func stringifiesBody() async throws {
    let value = self.context
      .evaluateScript(
        """
        new Response({}).text()
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
        new Response().text()
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
        new Response().bytes()
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
        new Response(new Uint8Array([0x66, 0x6F, 0x6F])).text()
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
        new Response(new Uint16Array([0x66, 0x6F, 0x6F])).text()
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
          const b = await new Response(\(initObject)).blob()
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
        new Response(JSON.stringify({ a: "b" })).json()
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
        new Response(new Blob([JSON.stringify({ a: "b" })])).json()
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
        new Response("foo").json()
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
      new Response("foo").bodyUsed
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
          const response = new Response("foo")
          try {
            await response.\(methodName)()
          } catch {}
          return response.bodyUsed
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
          const response = new Response("foo")
          try {
            await response.\(methodName)()
          } catch {}
          try {
            await response.\(methodName)()
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
      "Failed to execute '\(methodName)' on 'Response': body stream already read"
    )
  }

  @Test(
    "Response Cloning Allows Second Consumption of Body",
    arguments: ["text", "bytes", "blob", "arrayBuffer", "json", "formData"]
  )
  func cloneConsumeBodyTwice(methodName: String) async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const response = new Response("foo")
          const response2 = response.clone()
          try {
            await response.\(methodName)()
          } catch {}
          try {
            await response2.\(methodName)()
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
    "Cloning Consumed Response Carries Over Body Consumption Status",
    arguments: ["text", "bytes", "blob", "arrayBuffer", "json", "formData"]
  )
  func carriesBodyConsumptionStatus(methodName: String) async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const response = new Response("foo")
          try {
            await response.\(methodName)()
          } catch {}
          const response2 = response.clone()
          try {
            await response2.\(methodName)()
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
      "Failed to execute '\(methodName)' on 'Response': body stream already read"
    )
  }

  @Test("Fails to Construct FormData Body if Body is Not FormData")
  func failsFormDataBody() async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const response = new Response("foo")
          try {
            await response.formData()
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
      "Failed to execute 'formData' on 'Response': Failed to fetch"
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
          const response = new Response(formData)
          formData.set("a", "b")
          const formData2 = await response.formData()
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

  @Test("Response Clone Copies FormData")
  func copiesFormDataOnClone() async throws {
    let value = self.context
      .evaluateScript(
        """
        const run = async () => {
          const response = new Response(new FormData())
          const response2 = response.clone()
          const formData = await response.formData()
          formData.set("a", "b")
          const formData2 = await response2.formData()
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

  @Test("Status OK When in 200 Range")
  func statusOk() {
    for i in 200..<300 {
      let value = self.context.evaluateScript("new Response(undefined, { status: \(i) }).ok")
      expectNoDifference(value?.toBool(), true)
    }
  }

  @Test("Status Not Ok When Not in 200 Range")
  func statusNotOk() {
    for i in 300..<600 {
      let value = self.context.evaluateScript("new Response(undefined, { status: \(i) }).ok")
      expectNoDifference(value?.toBool(), false)
    }
  }

  #if canImport(UniformTypeIdentifiers)
    @Test(
      "FormData Body Text",
      arguments: [
        "response.text()",
        "response.blob().then((b) => b.text())",
        "response.bytes().then((b) => _jsCoreExtrasUint8ArrayToString(b))"
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
          const response = new Response(formData)
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
        new Response(new FormData()).headers.get("content-type")
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
        new Response(new FormData(), {
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
        new Response(\(initObject)).headers.get("content-type")
        """
      )
    expectNoDifference(value?.toString(), "text/plain; charset=UTF-8")
  }

  @Test("Sets Content-Type Header to Blob type When Body is Blob")
  func blobContentType() {
    let value = self.context
      .evaluateScript(
        """
        new Response(new Blob([], { type: "application/json" })).headers.get("content-type")
        """
      )
    expectNoDifference(value?.toString(), "application/json")
  }

  @Test(
    "Cannot Create Redirect Response From Invalid Status Code",
    arguments: [500, 200, 300, 305, 310]
  )
  func invalidRedirectStatusCode(status: Int) {
    expectErrorMessage(
      js: """
        Response.redirect("", \(status))
        """,
      message: "Failed to execute 'redirect' on 'Response': Invalid status code",
      in: self.context
    )
  }

  @Test("302 Status Code By Default for Redirect")
  func redirect302Code() {
    let value = self.context
      .evaluateScript(
        """
        Response.redirect("").status
        """
      )
    expectNoDifference(value?.toInt32(), 302)
  }

  @Test("Allows 3XX Status Codes For Redirect", arguments: [301, 302, 303, 307, 308])
  func redirectStatusCodes(status: Int32) {
    let value = self.context
      .evaluateScript(
        """
        Response.redirect("", \(status)).status
        """
      )
    expectNoDifference(value?.toInt32(), status)
  }

  @Test("Invalid JSON Response")
  func invalidJSON() {
    expectErrorMessage(
      js: "Response.json(undefined)",
      message: "Failed to execute 'json' on 'Response': The data is not JSON serializable",
      in: self.context
    )
  }

  @Test("Valid JSON Response")
  func validJSON() async throws {
    let value = self.context
      .evaluateScript(
        """
        Response.json({ a: "Hello" }).text()
        """
      )
      .toPromise()
    let resolvedValue = try await value?.resolvedValue
    expectNoDifference(
      resolvedValue?.toString(),
      """
      {"a":"Hello"}
      """
    )
  }

  @Test("JSON Response Uses application/json as the Content Type Header")
  func applicationJSON() async throws {
    let value = self.context
      .evaluateScript(
        """
        Response.json({ a: "Hello" }).headers.get("content-type")
        """
      )
    expectNoDifference(value?.toString(), "application/json")
  }

  @Test("JSON Response Does Not Override Predefined Content Type Header")
  func jsonDoesNotOverrideHeader() async throws {
    let value = self.context
      .evaluateScript(
        """
        Response.json({ a: "Hello" }, { headers: { "Content-Type": "application/pdf" } })
          .headers
          .get("content-type")
        """
      )
    expectNoDifference(value?.toString(), "application/pdf")
  }
}
