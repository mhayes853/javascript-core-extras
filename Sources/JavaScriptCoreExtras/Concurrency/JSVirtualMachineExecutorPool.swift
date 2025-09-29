@preconcurrency import JavaScriptCore

// MARK: - JSVirtualMachinePool

public final class JSVirtualMachineExecutorPool: @unchecked Sendable {
  private struct ExecutorCell {
    var referenceCount = 0
    let executor: JSVirtualMachineExecutor
  }

  private struct State {
    var index: Int
    var count: Int
    var cells: UnsafeMutablePointer<ExecutorCell?>

    init(count: Int) {
      self.index = 0
      self.count = count
      self.cells = .allocate(capacity: count)
    }
  }

  private let createVirtualMachine: @Sendable () -> JSVirtualMachine
  private let condition = NSCondition()
  private let state: Lock<State>
  private var isCreatingMachineCondition = false

  /// Creates a virutal machine pool.
  ///
  /// - Parameters:
  ///   - count: The maximum number of virtual machines to contain in the pool.
  ///   - createVirtualMachine: A function to create a custom virtual machine that is called every
  ///     time the pool creates a new `JSVirtualMachine`.
  public init(
    count: Int,
    createVirtualMachine: @escaping @Sendable () -> JSVirtualMachine = { JSVirtualMachine() }
  ) {
    precondition(count > 0, "There must be a minimum of at least 1 virtual machine in the pool.")
    self.createVirtualMachine = createVirtualMachine
    self.state = Lock(State(count: count))
  }

  deinit {
    self.state.withLock { $0.cells.deallocate() }
  }
}

// MARK: - Accessing an Executor

extension JSVirtualMachineExecutorPool {
  /// Returns a ``JSVirtualMachineExecutor`` from this pool.
  ///
  /// The executor returned is picked round-robin style.
  ///
  /// - Returns: A ``JSVirtualMachineExecutor``.
  public func executor() async -> JSVirtualMachineExecutor {
    let executor = self.state.withLock { state -> JSVirtualMachineExecutor? in
      guard let cell = state.cells[state.index] else { return nil }
      state.cells[state.index]?.referenceCount += 1
      state.index = self.nextCellIndex(in: state)
      return cell.executor
    }
    if let executor {
      return executor
    }
    return await withUnsafeContinuation { continuation in
      self.condition.lock()
      while self.isCreatingMachineCondition {
        self.condition.wait()
      }
      self.state.withLock { state in
        if let cell = state.cells[state.index] {
          continuation.resume(returning: cell.executor)
          state.cells[state.index]?.referenceCount += 1
          state.index = self.nextCellIndex(in: state)
          self.condition.signal()
        } else {
          self.isCreatingMachineCondition = true
          Thread.detachNewThread {
            self.condition.lock()
            let executor = self.state.withLock { state in
              let executor = JSVirtualMachineExecutor(
                createVirtualMachine: self.createVirtualMachine
              )
              state.cells[state.index] = ExecutorCell(referenceCount: 1, executor: executor)
              state.index = self.nextCellIndex(in: state)
              return executor
            }
            continuation.resume(returning: executor)
            self.isCreatingMachineCondition = false
            self.condition.signal()
            self.condition.unlock()
            executor.runBlocking()
          }
        }
      }
      self.condition.unlock()
    }
  }

  private func nextCellIndex(in state: State) -> Int {
    var index = state.index
    while state.cells[index] != nil {
      index = (index + 1) % state.count
      if state.index == index {
        return (state.index + 1) % state.count
      }
    }
    return index
  }
}

// MARK: - Object Management

extension JSVirtualMachineExecutorPool {
  public func release(executor: JSVirtualMachineExecutor) {
    self.condition.lock()
    self.state.withLock { state in
      for i in 0..<state.count {
        if state.cells[i]?.executor === executor {
          state.cells[i]?.referenceCount -= 1
        }
      }
    }
    self.condition.unlock()
  }

  public func garbageCollect() {
    self.condition.lock()
    self.state.withLock { state in
      for i in 0..<state.count {
        guard let cell = state.cells[i], cell.referenceCount <= 0 else { continue }
        cell.executor.stop()
        state.cells[i] = nil
      }
    }
    self.condition.unlock()
  }
}
