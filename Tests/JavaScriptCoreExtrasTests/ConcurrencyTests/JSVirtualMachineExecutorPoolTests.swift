import CustomDump
import IssueReporting
import JavaScriptCoreExtras
import Testing

@Suite("JSVirtualMachineExecutorPool tests")
struct JSVirtualMachineExecutorPoolTests {
  @Test("Uses Same Virtual Machine For Contexts When Only 1 Machine Allowed")
  func singleMachinePool() async {
    let pool = JSVirtualMachineExecutorPool(count: 1) { CustomVM() }
    let (m1, m2) = await (pool.executor(), pool.executor())
    await expectIdenticalVMs(m1, m2)
  }

  @Test("Performs A Round Robin When Pool Has Multiple Virtual Machines")
  func roundRobin() async {
    let pool = JSVirtualMachineExecutorPool(count: 3) { CustomVM() }
    let (c1, c2, c3, c4) = await (
      pool.executor(),
      pool.executor(),
      pool.executor(),
      pool.executor()
    )
    await expectDifferentVMs(c1, c2)
    await expectDifferentVMs(c2, c3)
    await expectDifferentVMs(c3, c1)
    await expectIdenticalVMs(c1, c4)
  }

  @Test("Supports Custom Virtual Machines")
  func customMachines() async {
    let pool = JSVirtualMachineExecutorPool(count: 1) { CustomVM() }
    let e1 = await pool.executor()
    await e1.withVirtualMachine { expectNoDifference($0 is CustomVM, true) }
  }

  @Test("Allows Concurrent Execution With Separate Virtual Machines")
  func concurrentExecution() async {
    let pool = JSVirtualMachineExecutorPool(count: 2)
    let (e1, e2) = await (pool.executor(), pool.executor())
    let (c1, c2) = (JSContextActor(executor: e1), JSContextActor(executor: e2))

    let ids = Lock([String]())
    let update: @convention(block) @Sendable (String) -> Void = { id in
      ids.withLock { $0.append(id) }
    }
    await c1.withContext { @Sendable in $1.setObject(update, forPath: "update") }
    await c2.withContext { @Sendable in $1.setObject(update, forPath: "update") }

    let task1 = Task {
      await c1.withContext { @Sendable in
        _ = $1.evaluateScript(
          """
          const id = "context1"
          for (let i = 0; i < 10_000; i++) {
            update(id)
          }
          """
        )
      }
    }
    let task2 = Task {
      await c2.withContext { @Sendable in
        _ = $1.evaluateScript(
          """
          const id = "context2"
          for (let i = 0; i < 10_000; i++) {
            update(id)
          }
          """
        )
      }
    }
    _ = await (task1.value, task2.value)
    ids.withLock {
      expectNoDifference($0.count, 20_000)
      let firstBlock = Array($0[0..<10_000])
      #expect(
        firstBlock != Array(repeating: "context1", count: 10_000),
        "context1 and context2 should be interleaved"
      )
      #expect(
        firstBlock != Array(repeating: "context2", count: 10_000),
        "context1 and context2 should be interleaved"
      )
    }
  }

  @Test("Does Not Create More Threads Than Machines")
  func doesNotCreateMoreThreadsThanMachines() async {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    await withTaskGroup { group in
      for _ in 0..<100 {
        group.addTask { await pool.executor() }
      }
      let machines = await group.reduce(into: [JSVirtualMachineExecutor]()) { $0.append($1) }
      let vm = await pool.executor()
      expectNoDifference(
        machines.allSatisfy { $0 === vm },
        true,
        "Each thread should have a separate VM, but since there's only 1 VM in this pool, they should all be the same VM."
      )
    }
  }

  @Test("Garbage Collects Any Executor That Has No References")
  func garbageCollection() async {
    let pool = JSVirtualMachineExecutorPool(count: 3)
    let e1 = await pool.executor()
    var e2: JSVirtualMachineExecutor
    var e3: JSVirtualMachineExecutor
    do {
      e2 = await pool.executor()
      e3 = await pool.executor()
      pool.release(executor: e2)
      pool.release(executor: e3)
    }
    pool.garbageCollect()
    let e4 = await pool.executor()
    let e5 = await pool.executor()
    let e6 = await pool.executor()
    expectNoDifference(e1 === e4, true)
    expectNoDifference(e5 === e2, false)
    expectNoDifference(e6 === e3, false)
  }

  @Test("Does Not Garbage Collect Executors That Have More Than Zero References")
  func doesNotGarbageCollectExecutorsWithReferences() async {
    let pool = JSVirtualMachineExecutorPool(count: 1)
    let e1 = await pool.executor()
    let e2 = await pool.executor()
    pool.release(executor: e2)
    pool.garbageCollect()

    let e3 = await pool.executor()
    expectNoDifference(e1 === e3, true)
  }
}

private final class CustomVM: JSVirtualMachine, @unchecked Sendable {}

private func expectIdenticalVMs(
  _ c1: JSVirtualMachineExecutor,
  _ c2: JSVirtualMachineExecutor
) async {
  let id1 = await c1.withVirtualMachine { $0 as! CustomVM }
  let id2 = await c2.withVirtualMachine { $0 as! CustomVM }
  expectNoDifference(id1 === id2, true)
}

private func expectDifferentVMs(
  _ c1: JSVirtualMachineExecutor,
  _ c2: JSVirtualMachineExecutor
) async {
  let id1 = await c1.withVirtualMachine { $0 as! CustomVM }
  let id2 = await c2.withVirtualMachine { $0 as! CustomVM }
  expectNoDifference(id1 === id2, false)
}
