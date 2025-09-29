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
