import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("JSContextActor tests")
struct JSContextActorTests {
  @Test("Cannot Construct From Executor With No Virtual Machine Available")
  func cannotConstructFromExecutorWithNoVirtualMachineAvailable() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    await Task {
      expectNoDifference(e.withVirtualMachineIfAvailable { _ in () } == nil, true)
      expectNoDifference(JSContextActor(executor: e) == nil, true)
    }
    .value
  }

  @Test("Cannot Construct From Executor When Context Uses Different Virtual Machine Than Executor")
  func cannotConstructFromExecutorWithDifferentVirtualMachine() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    await e.withVirtualMachine { _ in
      let context = JSContextActor(executor: e) { _ in JSContext() }
      expectNoDifference(context == nil, true)
    }
  }

  @Test("Basic JS Execution")
  func basicJSExecution() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    let context = await e.contextActor()
    await context.withIsolation { @Sendable in
      let value = $0.context.evaluateScript("1 === 2")
      expectNoDifference(value?.toBool(), false)
    }
  }

  @Test("Current Actor Is Nil When None Created")
  func currentActorIsNilWhenNoneCreated() async throws {
    expectNoDifference(JSContextActor.currentForJSInvoke() == nil, true)
  }

  @Test("Current Actor Is Nil When No Current JSContext")
  func currentActorIsNilWhenNoCurrentJSContext() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    await pool.executor()
      .withVirtualMachine { _ in
        expectNoDifference(JSContextActor.currentForJSInvoke() == nil, true)
      }
  }

  @Test("Current Actor Is Nil Within Context Accessor")
  func currentActorIsNilWithinContextAccessor() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    let context = await e.contextActor()
    await context.withIsolation { @Sendable _ in
      expectNoDifference(JSContextActor.currentForJSInvoke() == nil, true)
    }
  }

  @Test("Current Actor Is Present Within JS Function On Virtual Machine Executor")
  func currentActorIsPresentWithinJSFunctionOnVirtualMachineExecutor() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    let context = await e.contextActor()
    await context.withIsolation { @Sendable in
      let block: @convention(block) () -> Bool = { JSContextActor.currentForJSInvoke() == nil }
      $0.context.setObject(block, forPath: "block")
      let value = $0.context.evaluateScript("block()")
      expectNoDifference(value?.toBool(), false)
    }
  }

  @Test("Current Actor Is Not Present Within JS Function Off Executor")
  func currentActorIsPresentWithinJSFunctionOffExecutor() async throws {
    let context = JSContext()!
    let block: @convention(block) () -> Bool = { JSContextActor.currentForJSInvoke() == nil }
    context.setObject(block, forPath: "block")
    let value = context.evaluateScript("block()")
    expectNoDifference(value?.toBool(), true)
  }
}
