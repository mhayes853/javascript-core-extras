import CustomDump
import JavaScriptCoreExtras
import Testing
import XCTest

@Suite("JSPromiseValue tests")
struct JSPromiseValueTests {
  @Test("Does Not Convert From Non-Promise Value")
  func doesNotConvertFromNonPromiseValue() {
    let jsValue = JSValue(uInt32: 10, in: JSContext())!
    #expect(throws: Error.self) { try JSPromiseValue<Int>(jsValue: jsValue) }
  }

  @Test("JS Conversion")
  func convertsFromPromiseValue() throws {
    let context = JSContext()!
    let promise = JSPromiseValue<Int>.resolve(10, in: context)
    let jsValue = try promise.jsValue(in: context)

    expectNoDifference(jsValue.isPromise, true)

    #expect(throws: Never.self) {
      try JSPromiseValue<Int>(jsValue: jsValue)
    }
  }

  @Test("Does Not Convert JSValue When In Different Virtual Machine")
  func doesNotConvertJSValueWhenInDifferentVirtualMachine() {
    let promise = JSPromiseValue<Int>.resolve(10, in: JSContext())
    #expect(throws: Error.self) { try promise.jsValue(in: JSContext()) }
  }

  @Test("Converts JSValue When In Different Contexts On Same Virtual Machine")
  func convertsJSValueWhenInDifferentContextsOnSameVirtualMachine() {
    let vm = JSVirtualMachine()
    let promise = JSPromiseValue<Int>.resolve(10, in: JSContext(virtualMachine: vm))
    #expect(throws: Never.self) { try promise.jsValue(in: JSContext(virtualMachine: vm)) }
  }

  @Test("Resolve Resolves To Resolved Value")
  func resolveResolvesToResolvedValue() async throws {
    let promise = JSPromiseValue<Int>.resolve(10, in: JSContext())
    let value = try await promise.resolvedValue()
    expectNoDifference(value, 10)
  }

  @Test("Reject Rejects To Rejected Value")
  func rejectRejectsToRejectedValue() async throws {
    struct SomeError: Error {}
    let promise = JSPromiseValue<Int>.reject(SomeError(), in: JSContext())
    await #expect(throws: JSError.self) { try await promise.resolvedValue() }
  }

  @Test("Then Maps Value")
  func thenMapsValue() async throws {
    let promise = JSPromiseValue<Int>.resolve(10, in: JSContext())
      .then { "\($0)" }
    let value = try await promise.resolvedValue()
    expectNoDifference(value, "10")
  }

  @Test("Then Double Maps Value")
  func thenDoubleMapsValue() async throws {
    let promise = JSPromiseValue<Int>.resolve(10, in: JSContext())
      .then { "\($0)" }
      .then { $0.isEmpty }
    let value = try await promise.resolvedValue()
    expectNoDifference(value, false)
  }

  @Test("Then Maps Entire Promise")
  func thenMapsEntirePromise() async throws {
    let context = JSContext()!
    let promise = JSPromiseValue<Int>.resolve(10, in: context)
      .then { .resolve("\($0)", in: .current()) }
    let value = try await promise.resolvedValue()
    expectNoDifference(value, "10")
  }

  @Test("Then Maps Error")
  func thenMapsError() async throws {
    struct SomeError: Error {}
    let context = JSContext()!
    let promise = JSPromiseValue<Int>.reject(SomeError(), in: context)
      .then(onResolved: nil) { _ in "10" }
    let value = try await promise.resolvedValue()
    expectNoDifference(value, "10")
  }

  @Test("Then Maps Entire Promise Through Error")
  func thenMapsEntirePromiseThroughError() async throws {
    struct SomeError: Error {}
    let context = JSContext()!
    let promise = JSPromiseValue<Int>.reject(SomeError(), in: context)
      .then(onResolved: nil) { _ in .resolve("10", in: .current()) }
    let value = try await promise.resolvedValue()
    expectNoDifference(value, "10")
  }

  @Test("Then Maps To Rejected When Throwing In Resolve")
  func thenMapsToRejectedWhenThrowingInResolve() async throws {
    struct SomeError: Error {}
    let context = JSContext()!
    let promise = JSPromiseValue<Int>.resolve(10, in: context)
      .then { _ -> String in throw SomeError() }
    await #expect(throws: JSError.self) { try await promise.resolvedValue() }
  }

  @Test("Then Maps To Rejected When Throwing In Reject")
  func thenMapsToRejectedWhenThrowingInReject() async throws {
    struct SomeError: Error {}
    let context = JSContext()!
    let promise = JSPromiseValue<Int>.reject(SomeError(), in: context)
      .then(onResolved: nil) { _ -> String in throw SomeError() }
    await #expect(throws: JSError.self) { try await promise.resolvedValue() }
  }

  @Test("Resolve Value From Closure")
  func testResolveValueFromClosure() async throws {
    let contextActor = await self.contextActor()
    try await contextActor.withIsolation { @Sendable contextActor in
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

    let contextActor = await self.contextActor()
    await contextActor.withIsolation { @Sendable contextActor in
      let promise = JSPromiseValue<Int>(in: contextActor.value) { resolvers in
        await resolvers.reject(SomeError())
      }
      await #expect(throws: JSError.self) { try await promise.resolvedValue() }
    }
  }

  @Test("Reports Issue When Resolving Twice")
  func reportsIssueWhenResolvingTwice() async throws {
    let contextActor = await self.contextActor()
    await contextActor.withIsolation { @Sendable contextActor in
      await withKnownIssue {
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

    let contextActor = await self.contextActor()
    await contextActor.withIsolation { @Sendable contextActor in
      await withKnownIssue {
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

    let contextActor = await self.contextActor()
    await contextActor.withIsolation { @Sendable contextActor in
      await withKnownIssue {
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

  private func contextActor() async -> JSActor<JSContext> {
    await JSVirtualMachineExecutorPool(count: 1).executor().contextActor()
  }
}
