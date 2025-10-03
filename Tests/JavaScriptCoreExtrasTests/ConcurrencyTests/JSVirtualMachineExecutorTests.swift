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
    let value: Void? = await executor.withVirtualMachine { _ in
      executor.withVirtualMachineIfCurrentExecutor { _ in () }
    }
    expectNoDifference(value != nil, true)
  }

  @Test("Has No Virtual Machine When Not Running On Same Thread")
  func hasNoVirtualMachineWhenNotRunningOnSameThread() async {
    let executor = JSVirtualMachineExecutor()
    Task { try await executor.run() }
    await Task.megaYield()
    let value: Void? = executor.withVirtualMachineIfCurrentExecutor { _ in () }
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

    let value: Void? = await e1.withVirtualMachine { _ in
      e2.withVirtualMachineIfCurrentExecutor { _ in () }
    }
    expectNoDifference(value != nil, false)
  }

  @Test("Virtual Machine Is Available From Within JS Function Call")
  func virtualMachineIsAvailableFromWithinJSFunctionCall() async {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()

    await e.withVirtualMachine { vm in
      let context = JSContext(virtualMachine: vm)

      let block: @convention(block) () -> Bool = {
        let value: Void? = e.withVirtualMachineIfCurrentExecutor { _ in () }
        return value != nil
      }
      context?.setObject(block, forPath: "block")
      let value = context?.evaluateScript("block()")
      expectNoDifference(value?.toBool(), true)
    }
  }

  @Test("Current Executor Is Nil When Not Running")
  func currentExecutorIsNilWhenNotRunning() async {
    let e = JSVirtualMachineExecutor()
    self.expectCurrentExecutorMatch(with: nil, context: JSContext())
    _ = e
  }

  @Test("Current Executor Is Nil When Stopped")
  func currentExecutorIsNilWhenStopped() async {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    e.stop()
    self.expectCurrentExecutorMatch(with: nil, context: JSContext())
    _ = e
  }

  @Test("Current Executor Matches Running Executor")
  func currentExecutorMatchesRunningExecutor() async {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()

    await e.withVirtualMachine { vm in
      self.expectCurrentExecutorMatch(with: e, context: JSContext(virtualMachine: vm))
    }
  }

  @Test("Isolates Executors To Different Virtual Machines")
  func isolatesExecutorsToDifferentVirtualMachines() async {
    let pool = JSVirtualMachineExecutorPool(count: 2)
    let e1 = await pool.executor()
    let e2 = await pool.executor()

    await e1.withVirtualMachine { vm in
      self.expectCurrentExecutorMatch(with: e1, context: JSContext(virtualMachine: vm))
    }
    await e2.withVirtualMachine { vm in
      self.expectCurrentExecutorMatch(with: e2, context: JSContext(virtualMachine: vm))
    }
  }

  private func expectCurrentExecutorMatch(
    with executor: JSVirtualMachineExecutor?,
    context: JSContext?
  ) {
    let block: @convention(block) () -> Bool = {
      JSVirtualMachineExecutor.current() === executor
    }
    context?.setObject(block, forPath: "block")
    let value = context?.evaluateScript("block()")
    expectNoDifference(value?.toBool(), true)
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
