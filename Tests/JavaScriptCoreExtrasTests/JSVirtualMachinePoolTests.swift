import CustomDump
import IssueReporting
@preconcurrency import JavaScriptCoreExtras
import Testing

@Suite("JSVirtualMachinePool tests")
struct JSVirtualMachinePoolTests {
  @Test("Uses Same Virtual Machine For Contexts When Only 1 Machine Allowed")
  func singleMachinePool() async {
    let pool = JSVirtualMachinePool(machines: 1)
    let (c1, c2) = await (JSContext(in: pool), JSContext(in: pool))
    expectIdenticalVMs(c1, c2)
  }

  @Test("Performs A Round Robin When Pool Has Multiple Virtual Machines")
  func roundRobin() async {
    let pool = JSVirtualMachinePool(machines: 3)
    let (c1, c2, c3, c4) = await (
      JSContext(in: pool), JSContext(in: pool), JSContext(in: pool), JSContext(in: pool)
    )
    expectDifferentVMs(c1, c2)
    expectDifferentVMs(c2, c3)
    expectDifferentVMs(c3, c1)
    expectIdenticalVMs(c1, c4)
  }

  @Test("Supports Custom Virtual Machines")
  func customMachines() async {
    let pool = JSVirtualMachinePool(machines: 2) { CustomVM() }
    let (c1, c2) = await (JSContext(in: pool), JSContext(in: pool))
    expectDifferentVMs(c1, c2)
    expectNoDifference(c1.virtualMachine is CustomVM, true)
    expectNoDifference(c2.virtualMachine is CustomVM, true)
  }

  @Test("Allows Concurrent Execution With Separate Virtual Machines")
  func concurrentExecution() async {
    let pool = JSVirtualMachinePool(machines: 2)
    let (c1, c2) = await (SendableContext(in: pool), SendableContext(in: pool))

    let ids = Lock([String]())
    let update: @convention(block) (String) -> Void = { id in
      ids.withLock { $0.append(id) }
    }
    c1.setObject(update, forPath: "update")
    c2.setObject(update, forPath: "update")

    let task1 = Task {
      _ = c1.evaluateScript(
        """
        const id = "context1"
        for (let i = 0; i < 1000; i++) {
          update(id)
        }
        """
      )
    }
    let task2 = Task {
      _ = c2.evaluateScript(
        """
        const id = "context2"
        for (let i = 0; i < 1000; i++) {
          update(id)
        }
        """
      )
    }
    _ = await (task1.value, task2.value)
    ids.withLock {
      expectNoDifference($0.count, 2000)
      let firstBlock = Array($0[0..<1000])
      #expect(
        firstBlock != Array(repeating: "context1", count: 1000),
        "context1 and context2 should be interleaved"
      )
      #expect(
        firstBlock != Array(repeating: "context2", count: 1000),
        "context1 and context2 should be interleaved"
      )
    }
  }

  @Test("Does Not Create More Threads Than Machines")
  func doesNotCreateMoreThreadsThanMachines() async {
    let pool = JSVirtualMachinePool(machines: 1) { CustomVM() }
    await withTaskGroup(of: CustomVM.self) { group in
      for _ in 0..<100 {
        group.addTask { await pool.virtualMachine() as! CustomVM }
      }
      let machines = await group.reduce(into: [JSVirtualMachine]()) { $0.append($1) }
      let vm = await pool.virtualMachine()
      expectNoDifference(
        machines.allSatisfy { $0 === vm },
        true,
        "Each thread should have a separate VM, but since there's only 1 VM in this pool, they should all be the same VM."
      )
    }
  }

  @Test("Garbage Collects Any Virtual Machine That Has No References")
  func garbageCollection() async {
    let pool = JSVirtualMachinePool(machines: 3) { CounterVM() }
    let vm1 = await pool.virtualMachine()
    var id2: Int
    var id3: Int
    do {
      id2 = await (pool.virtualMachine() as! CounterVM).id
      id3 = await (pool.virtualMachine() as! CounterVM).id
    }
    pool.garbageCollect()
    let vm2 = await pool.virtualMachine()
    let vm3 = await pool.virtualMachine()
    let vm4 = await pool.virtualMachine()
    expectNoDifference((vm1 as! CounterVM).id, (vm2 as! CounterVM).id)
    expectNoDifference((vm3 as! CounterVM).id != id2, true)
    expectNoDifference((vm4 as! CounterVM).id != id3, true)
  }
}

private final class CounterVM: JSVirtualMachine, @unchecked Sendable {
  private static let idCounter = Lock(0)

  let id: Int

  override init() {
    self.id = Self.idCounter.withLock { id in
      defer { id += 1 }
      return id
    }
    super.init()
  }
}

private final class CustomVM: JSVirtualMachine, @unchecked Sendable {}

private func expectIdenticalVMs(_ c1: JSContext, _ c2: JSContext) {
  expectNoDifference(c1.virtualMachine === c2.virtualMachine, true)
}

private func expectIdenticalVMs(_ c1: JSVirtualMachine, _ c2: JSVirtualMachine) {
  expectNoDifference(c1 === c2, true)
}

private func expectDifferentVMs(_ c1: JSContext, _ c2: JSContext) {
  expectNoDifference(c1.virtualMachine === c2.virtualMachine, false)
}

private final class SendableContext: JSContext, @unchecked Sendable {}

extension JSContext {
  convenience init(in pool: JSVirtualMachinePool) async {
    await self.init(virtualMachine: pool.virtualMachine())
  }
}
