@preconcurrency import JavaScriptCore

// MARK: - JSVirtualMachinePool

/// An object pool of ``JSVirtualMachineExecutor`` instances.
///
/// You can run JavaScript concurrently by createing multiple `JSContext` instances that use
/// separate `JSVirtualMachine` instances on different threads. However, this is potential
/// bottleneck if your application needs to create a separate thread to run many different
/// `JSContext` instances at once.
///
/// You can use this class to limit the number of executor instances and threads that are
/// created by your application to execute JavaScript. Additionally, you can call
/// ``garbageCollect()`` to free any inactive executors from the pool.
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

  /// Creates a pool.
  ///
  /// - Parameters:
  ///   - count: The maximum number of executors to contain in the pool.
  ///   - createVirtualMachine: A function to create a custom virtual machine that is called every
  ///     time the pool creates a new ``JSVirtualMachineExecutor``.
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
  /// Returns a ``JSVirtualMachineExecutor`` from this pool, and increments its reference count by 1.
  ///
  /// The returned executor will have its reference count incremented by 1, you can call
  /// ``release(executor:)`` to decrement the reference count for the retuened executor.
  ///
  /// When this pool creates a new executor through this method, it will automatically begin
  /// running the executor for you.
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
  /// Decrements the reference count for a ``JSVirtualMachineExecutor`` by 1 in this pool.
  ///
  /// Obtaining an executor from the pool through calling ``executor()`` increments the reference
  /// count by 1 for the returned executor. You can pass the returned executor to this method to
  /// decrement the reference count of the executor by 1.
  ///
  /// - Parameter executor: The executor.
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
  
  /// Stops and removes any ``JSVirtualMachineExecutor`` instances from this pool with a reference
  /// count of 0 or lower.
  ///
  /// Obtaining an executor from the pool through calling ``executor()`` increments the reference
  /// count by 1 for the returned executor.
  ///
  /// Calling ``release(executor:)`` with an executor decrements the reference count by 1 for the
  /// specified executor.
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
