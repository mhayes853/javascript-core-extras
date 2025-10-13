import CustomDump
import JavaScriptCoreExtras
import Testing
import XCTest

@Suite("JSPromiseValue tests")
struct JSPromiseValueTests {
  @Test("Does Not Convert From Non-Promise Value")
  func doesNotConvertFromNonPromiseValue() async throws {
    try await withContextActor {
      let jsValue = JSValue(uInt32: 10, in: $0.value)!
      #expect(throws: Error.self) { try JSPromiseValue<Int>(jsValue: jsValue) }
    }
  }

  @Test("JS Conversion")
  func convertsFromPromiseValue() async throws {
    try await withContextActor {
      let promise = JSPromiseValue<Int>.resolve(10, in: $0.value)
      let jsValue = try promise.jsValue(in: $0.value)

      expectNoDifference(jsValue.isPromise, true)

      #expect(throws: Never.self) {
        try JSPromiseValue<Int>(jsValue: jsValue)
      }
    }
  }

  @Test("Does Not Convert JSValue When In Different Virtual Machine")
  func doesNotConvertJSValueWhenInDifferentVirtualMachine() async throws {
    try await withContextActor { _ in
      let promise = JSPromiseValue<Int>.resolve(10, in: JSContext())
      #expect(throws: Error.self) { try promise.jsValue(in: JSContext()) }
    }
  }

  @Test("Converts JSValue When In Different Contexts On Same Virtual Machine")
  func convertsJSValueWhenInDifferentContextsOnSameVirtualMachine() async throws {
    try await withContextActor { contextActor in
      let vm = contextActor.executor.withVirtualMachineIfCurrentExecutor { $0 }!
      let promise = JSPromiseValue<Int>.resolve(10, in: JSContext(virtualMachine: vm))
      #expect(throws: Never.self) { try promise.jsValue(in: JSContext(virtualMachine: vm)) }
    }
  }

  @Test("Resolve Resolves To Resolved Value")
  func resolveResolvesToResolvedValue() async throws {
    try await withContextActor {
      let promise = JSPromiseValue<Int>.resolve(10, in: $0.value)
      let value = try await promise.resolvedValue()
      expectNoDifference(value, 10)
    }
  }

  @Test("Reject Rejects To Rejected Value")
  func rejectRejectsToRejectedValue() async throws {
    struct SomeError: Error {}
    try await withContextActor {
      let promise = JSPromiseValue<Int>.reject(SomeError(), in: $0.value)
      await #expect(throws: JSError.self) { try await promise.resolvedValue() }
    }
  }

  @Test("Then Maps Value")
  func thenMapsValue() async throws {
    try await withContextActor {
      let promise = JSPromiseValue<Int>.resolve(10, in: $0.value)
        .then { "\($0)" }
      let value = try await promise.resolvedValue()
      expectNoDifference(value, "10")
    }
  }

  @Test("Then Double Maps Value")
  func thenDoubleMapsValue() async throws {
    try await withContextActor {
      let promise = JSPromiseValue<Int>.resolve(10, in: $0.value)
        .then { "\($0)" }
        .then { $0.isEmpty }
      let value = try await promise.resolvedValue()
      expectNoDifference(value, false)
    }
  }

  @Test("Then Maps Entire Promise")
  func thenMapsEntirePromise() async throws {
    try await withContextActor {
      let promise = JSPromiseValue<Int>.resolve(10, in: $0.value)
        .then { .resolve("\($0)", in: .current()) }
      let value = try await promise.resolvedValue()
      expectNoDifference(value, "10")
    }
  }

  @Test("Then Maps Error")
  func thenMapsError() async throws {
    struct SomeError: Error {}
    try await withContextActor {
      let promise = JSPromiseValue<Int>.reject(SomeError(), in: $0.value)
        .then(onResolved: nil) { _ in "10" }
      let value = try await promise.resolvedValue()
      expectNoDifference(value, "10")
    }
  }

  @Test("Then Maps Entire Promise Through Error")
  func thenMapsEntirePromiseThroughError() async throws {
    struct SomeError: Error {}

    try await withContextActor {
      let promise = JSPromiseValue<Int>.reject(SomeError(), in: $0.value)
        .then(onResolved: nil) { _ in .resolve("10", in: .current()) }
      let value = try await promise.resolvedValue()
      expectNoDifference(value, "10")
    }
  }

  @Test("Then Maps To Rejected When Throwing In Resolve")
  func thenMapsToRejectedWhenThrowingInResolve() async throws {
    struct SomeError: Error {}
    try await withContextActor {
      let promise = JSPromiseValue<Int>.resolve(10, in: $0.value)
        .then { _ -> String in throw SomeError() }
      await #expect(throws: JSError.self) { try await promise.resolvedValue() }
    }
  }

  @Test("Then Maps To Rejected When Throwing In Reject")
  func thenMapsToRejectedWhenThrowingInReject() async throws {
    struct SomeError: Error {}
    try await withContextActor {
      let promise = JSPromiseValue<Int>.reject(SomeError(), in: $0.value)
        .then(onResolved: nil) { _ -> String in throw SomeError() }
      await #expect(throws: JSError.self) {
        try await promise.resolvedValue()
      }
    }
  }

  @Test("Resolve Value From Closure")
  func testResolveValueFromClosure() async throws {
    try await withContextActor { @Sendable contextActor in
      let promise = JSPromiseValue<Int>(in: contextActor.value) { resolvers in
        await resolvers.resolve(10)
      }
      let value = try await promise.resolvedValue()
      expectNoDifference(value, 10)
    }
  }

  @Test("Reject Value From Closure")
  func rejectValueFromClosure() async throws {
    struct SomeError: Error {}

    try await withContextActor {
      let promise = JSPromiseValue<Int>(in: $0.value) { resolvers in
        await resolvers.reject(SomeError())
      }
      await #expect(throws: JSError.self) { try await promise.resolvedValue() }
    }
  }

  @Test("Reports Issue When Resolving Twice")
  func reportsIssueWhenResolvingTwice() async throws {
    await withKnownIssue {
      try await withContextActor { @Sendable contextActor in
        await withUnsafeContinuation { continuation in
          _ = JSPromiseValue<Int>(in: contextActor.value) { resolvers in
            await resolvers.resolve(10)
            await resolvers.resolve(10)
            continuation.resume()
          }
        }
      }
    }
  }

  @Test("Reports Issue When Rejecting Twice")
  func reportsIssueWhenRejectingTwice() async throws {
    struct SomeError: Error {}

    await withKnownIssue {
      try await withContextActor { @Sendable contextActor in
        await withUnsafeContinuation { continuation in
          _ = JSPromiseValue<Int>(in: contextActor.value) { resolvers in
            await resolvers.reject(SomeError())
            await resolvers.reject(SomeError())
            continuation.resume()
          }
        }
      }
    }
  }

  @Test("Reports Issue When Resolving And Rejecting")
  func reportsIssueWhenResolvingAndRejecting() async throws {
    struct SomeError: Error {}

    await withKnownIssue {
      try await withContextActor { @Sendable contextActor in
        await withUnsafeContinuation { continuation in
          _ = JSPromiseValue<Int>(in: contextActor.value) { resolvers in
            await resolvers.resolve(10)
            await resolvers.reject(SomeError())
            continuation.resume()
          }
        }
      }
    }
  }
}
