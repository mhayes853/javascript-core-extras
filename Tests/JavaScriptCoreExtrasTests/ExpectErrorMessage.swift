import CustomDump
import IssueReporting
import JavaScriptCoreExtras
import Testing

func expectErrorMessage(js: String, message expected: String, in context: JSContext) {
  var message: String?
  var didFind = false
  context.exceptionHandler = { _, value in
    guard !didFind else { return }
    message = value?.objectForKeyedSubscript("message")?.toString()
    didFind = message == expected
  }
  context.evaluateScript(js)
  expectNoDifference(message, expected)
}

func expectPromiseRejectedErrorMessage(
  js: String,
  message expected: String,
  in context: JSContext
) async throws {
  let value = try #require(context.evaluateScript(js).toPromise())
  do {
    _ = try await value.resolvedValue
    reportIssue("Expected promise to reject, but promise resolved successfully.")
  } catch let error as JSPromiseRejectedError {
    expectNoDifference(error.reason.objectForKeyedSubscript("message").toString(), expected)
  } catch {
    reportIssue(
      "JSPromiseRejectedError was not thrown. Threw \(String(reflecting: type(of: error))) instead."
    )
  }
}
