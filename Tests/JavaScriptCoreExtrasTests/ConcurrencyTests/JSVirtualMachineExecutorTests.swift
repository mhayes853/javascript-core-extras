import CustomDump
import JavaScriptCoreExtras
import Testing
import XCTest

@Suite("JSVirtualMachineExecutor tests")
struct JSVirtualMachineExecutorTests {
  @Test("Is Not Running By Default")
  func isNotRunningByDefault() async {
    let executor = JSVirtualMachineExecutor()
    expectNoDifference(executor.isRunning, false)
  }

  @Test("Is Running When Running Started")
  func isRunningWhenStarted() async {
    let executor = JSVirtualMachineExecutor()
    Task { try await executor.run() }
    await Task.megaYield()
    expectNoDifference(executor.isRunning, true)
  }

  @Test("Is Not Running When Stopped")
  func isNotRunningWhenStopped() async {
    let executor = JSVirtualMachineExecutor()
    Task { try await executor.run() }
    await Task.megaYield()
    executor.stop()
    expectNoDifference(executor.isRunning, false)
  }

  @Test("Is Not Running After Cancellation")
  func isNotRunningAfterCancellation() async {
    let executor = JSVirtualMachineExecutor()
    let task = Task { try await executor.run() }
    await Task.megaYield()
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    expectNoDifference(executor.isRunning, false)
  }

  @Test("Immediate Cancellation Throws Error")
  func immediateCancellationThrowsError() async {
    let executor = JSVirtualMachineExecutor()
    let task = Task { try await executor.run() }
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  @Test("Has Virtual Machine When Running On Same Thread")
  func hasVirtualMachineWhenRunningOnSameThread() async {
    let executor = JSVirtualMachineExecutor()
    Task { try await executor.run() }
    await Task.megaYield()
    let value = await executor.withVirtualMachine { _ in
      executor.withVirtualMachineIfAvailable { _ in () }
    }
    expectNoDifference(value != nil, true)
  }

  @Test("Has No Virtual Machine When Not Running On Same Thread")
  func hasNoVirtualMachineWhenNotRunningOnSameThread() async {
    let executor = JSVirtualMachineExecutor()
    Task { try await executor.run() }
    await Task.megaYield()
    let value = executor.withVirtualMachineIfAvailable { _ in () }
    expectNoDifference(value != nil, false)
  }

  @Test("Has No Virtual Machine When Not Using The Right Virtual Machine For Executor")
  func hasNoVirtualMachineWhenNotUsingTheRightVirtualMachineForExecutor() async {
    let e1 = JSVirtualMachineExecutor()
    let e2 = JSVirtualMachineExecutor()

    Task { try await e1.run() }
    Task { try await e2.run() }
    await Task.megaYield()
    await Task.megaYield()

    let value = await e1.withVirtualMachine { _ in
      e2.withVirtualMachineIfAvailable { _ in () }
    }
    expectNoDifference(value != nil, false)
  }
}

final class JSVirtualMachineExecutorXCTests: XCTestCase {
  func testTerminatesWhenStopped() async {
    let begins = self.expectation(description: "begins")
    let ends = self.expectation(description: "ends")
    let executor = JSVirtualMachineExecutor()
    Task {
      begins.fulfill()
      executor.runBlocking()
      ends.fulfill()
    }
    await self.fulfillment(of: [begins])
    executor.stop()
    await self.fulfillment(of: [ends])
  }
}
