import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("JSGlobalActor tests")
struct JSGlobalActorTests {
  @Test("Has Current Executor When Isolated")
  func hasCurrentExecutorWhenIsolated() async throws {
    let task = Task { @JSGlobalActor in
      JSVirtualMachineExecutor.current()
    }
    _ = try #require(await task.value)
  }

  @Test("Has Executor When Isolated")
  func hasExecutorWhenIsolated() async throws {
    let task = Task { @JSGlobalActor in
      JSGlobalActor.executor.isRunning
    }
    let isRunning = await task.value
    expectNoDifference(isRunning, true)
  }

  @Test("Runs JavaScript Operations On Global Actor")
  func runsJavaScriptOperationsOnGlobalActor() async throws {
    await JSGlobalActor.run {
      let context = JSContext(virtualMachine: JSGlobalActor.virtualMachine)!
      context.setFunction(forKey: "isIsolated") {
        JSGlobalActor.executor === JSVirtualMachineExecutor.current()
      }
      let value = context.evaluateScript("isIsolated()").toBool()
      expectNoDifference(value, true)
    }
  }
}
