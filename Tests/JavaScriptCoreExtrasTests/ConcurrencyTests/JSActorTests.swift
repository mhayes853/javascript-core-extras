import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("JSContextActor tests")
struct JSContextActorTests {
  @Test("Basic JS Execution")
  func basicJSExecution() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    let context = await e.contextActor()
    await context.withIsolation { @Sendable in
      let value = $0.value.evaluateScript("1 === 2")
      expectNoDifference(value?.toBool(), false)
    }
  }

  @Test("Has Isolation With Virtual Machine")
  func hasIsolationWithVirtualMachine() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    let context = await e.contextActor()

    await context.withIsolation { @Sendable a in
      expectNoDifference(a.value.virtualMachine === a.virtualMachine, true)
    }
  }

  @Test("Current Context Is Nil When None Created")
  func currentActorIsNilWhenNoneCreated() async throws {
    expectNoDifference(JSActor.currentContext() == nil, true)
  }

  @Test("Current Context Is Nil When No Current JSContext")
  func currentActorIsNilWhenNoCurrentJSContext() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    await pool.executor()
      .withVirtualMachine { _ in
        expectNoDifference(JSActor.currentContext() == nil, true)
      }
  }

  @Test("Current Context Is Nil Within Context Accessor")
  func currentActorIsNilWithinContextAccessor() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    let context = await e.contextActor()
    await context.withIsolation { @Sendable _ in
      expectNoDifference(JSActor.currentContext() == nil, true)
    }
  }

  @Test("Current Context Is Present Within JS Function On Virtual Machine Executor")
  func currentActorIsPresentWithinJSFunctionOnVirtualMachineExecutor() async throws {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e = await pool.executor()
    let context = await e.contextActor()
    await context.withIsolation { @Sendable in
      let block: @convention(block) () -> Bool = { JSActor.currentContext() == nil }
      $0.value.setObject(block, forPath: "block")
      let value = $0.value.evaluateScript("block()")
      expectNoDifference(value?.toBool(), false)
    }
  }

  @Test("Current Context Is Not Present Within JS Function Off Executor")
  func currentContextIsPresentWithinJSFunctionOffExecutor() async throws {
    let context = JSContext()!
    let block: @convention(block) () -> Bool = { JSActor.currentContext() == nil }
    context.setObject(block, forPath: "block")
    let value = context.evaluateScript("block()")
    expectNoDifference(value?.toBool(), true)
  }
}
