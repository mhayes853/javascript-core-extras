import IssueReporting
import JavaScriptCoreExtras
import Testing

@Suite("JSPromise tests")
struct JSPromiseTests {
  private let context = JSContext()!

  @Test("From Invalid JSValues")
  func invalid() {
    let values: [@Sendable (JSContext) -> JSValue?] = [
      { JSValue(bool: false, in: $0) },
      { JSValue(int32: 4, in: $0) },
      { JSValue(nullIn: $0) },
      { JSValue(undefinedIn: $0) },
      { JSValue(newArrayIn: $0) },
      { JSValue(newObjectIn: $0) },
      { JSValue(object: TestClass(), in: $0) }
    ]
    for value in values {
      let promise = value(self.context)?.toPromise()
      #expect(promise == nil)
    }
  }

  @Test("Reject")
  func rejected() async throws {
    let promise = try #require(
      JSValue(newPromiseRejectedWithReason: "bad", in: self.context).toPromise()
    )
    await #expect(throws: JSPromiseRejectedError.self) { try await promise.resolvedValue }
  }

  @Test("Resolve")
  func resolved() async throws {
    let promise = try #require(
      JSValue(newPromiseResolvedWithResult: "good", in: self.context).toPromise()
    )
    let value = try await promise.resolvedValue
    #expect(value.toString() == "good")
  }

  @Test("Evaluated Resolved")
  func evaluatedResolved() async throws {
    let value = try await self.context
      .evaluateScript(
        """
        const foo = async () => "hello"
        foo()
        """
      )
      .toPromise()?
      .resolvedValue
    #expect(value?.toString() == "hello")
  }

  @Test("Then")
  func then() async throws {
    let value = try await JSPromise.resolve("hello", in: self.context)
      .then { JSValue(object: ($0.toString() ?? "") + " world", in: $0.context) }
      .resolvedValue
    #expect(value.toString() == "hello world")
  }

  @Test("Then Nil")
  func thenNil() async throws {
    let value = try await JSPromise.resolve("hello", in: self.context)
      .then { _ in nil }
      .resolvedValue
    #expect(value.isUndefined)
  }

  @Test("Evaluated Rejected")
  func evaluatedRejected() async throws {
    await #expect(throws: JSPromiseRejectedError.self) {
      try await self.context
        .evaluateScript(
          """
          const foo = async () => {
            throw "hello"
          }
          foo()
          """
        )
        .toPromise()?
        .resolvedValue
    }
  }

  @Test("Catch")
  func `catch`() async throws {
    let value = try await JSPromise.reject("hello", in: self.context)
      .catch { JSValue(object: ($0.toString() ?? "") + " world", in: $0.context) }
      .resolvedValue
    #expect(value.toString() == "hello world")
  }

  @Test("Catch Nil")
  func catchNil() async throws {
    let value = try await JSPromise.reject("hello", in: self.context)
      .catch { _ in nil }
      .resolvedValue
    #expect(value.isUndefined)
  }

  @Test("Catch Catch")
  func catchCatch() async throws {
    let value = try await JSPromise.reject("hello", in: self.context)
      .catch {
        $0.context.exception = $0
        return JSValue(undefinedIn: $0.context)
      }
      .catch { JSValue(object: ($0.toString() ?? "") + " world", in: $0.context) }
      .resolvedValue
    #expect(value.toString() == "hello world")
  }

  @Test("Catch Then")
  func catchThen() async throws {
    let value = try await JSPromise.reject("hello", in: self.context)
      .catch { $0 }
      .then { JSValue(object: ($0.toString() ?? "") + " world", in: $0.context) }
      .resolvedValue
    #expect(value.toString() == "hello world")
  }

  @Test("Then Catch")
  func thenCatch() async throws {
    let value = try await JSPromise.resolve("hello", in: self.context)
      .then {
        $0.context.exception = $0
        return JSValue(undefinedIn: $0.context)
      }
      .catch { JSValue(object: ($0.toString() ?? "") + " world", in: $0.context) }
      .resolvedValue
    #expect(value.toString() == "hello world")
  }

  @Test("Finally")
  func finally() async throws {
    let value = try await confirmation { confirm in
      try await JSPromise.resolve("hello", in: self.context)
        .then {
          $0.context.exception = $0
          return JSValue(undefinedIn: $0.context)
        }
        .catch { JSValue(object: ($0.toString() ?? "") + " world", in: $0.context) }
        .finally { confirm() }
        .resolvedValue
    }
    #expect(value.toString() == "hello world")
  }

  @Test("Resolved Continuation")
  func resolvedContinuation() async throws {
    let value = try await JSPromise(in: self.context) { continuation in
      Task { continuation.resume(resolving: JSValue(int32: 5, in: continuation.context)) }
    }
    .resolvedValue
    #expect(value.toInt32() == 5)
  }

  @Test("Rejected Continuation")
  func rejectedContinuation() async throws {
    let value = try await JSPromise(in: self.context) { continuation in
      Task { continuation.resume(rejecting: 5) }
    }
    .catch { $0 }
    .resolvedValue
    #expect(value.toInt32() == 5)
  }

  @Test("Resume Continuation With Successful Result")
  func successfulResult() async throws {
    let value = try await JSPromise(in: self.context) { continuation in
      Task { continuation.resume(result: .success(JSValue(int32: 5, in: continuation.context))) }
    }
    .resolvedValue
    #expect(value.toInt32() == 5)
  }

  @Test("Resume Continuation With Failing Result")
  func failingResult() async throws {
    let value = try await JSPromise(in: self.context) { continuation in
      Task {
        continuation.resume(
          result: .failure(
            JSValueError(value: JSValue(int32: 5, in: continuation.context))
          )
        )
      }
    }
    .catch { $0 }
    .resolvedValue
    #expect(value.toInt32() == 5)
  }

  @Test("Reports Issue When Continuation Resumed More Than Once")
  func resumeMoreThanOnce() async throws {
    await withExpectedIssue {
      _ = try await JSPromise(in: self.context) { continuation in
        continuation.resume(resolving: JSValue(int32: 5, in: continuation.context))
        continuation.resume(rejecting: JSValue(nullIn: continuation.context))
      }
      .resolvedValue
    }
  }
}

@objc private protocol TestClassExport: JSExport {}

@objc class TestClass: NSObject, TestClassExport {}
