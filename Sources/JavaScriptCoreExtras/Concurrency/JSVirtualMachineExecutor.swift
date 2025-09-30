import Foundation
import JavaScriptCore

// MARK: - JSVirtualMachineExecutor

public final class JSVirtualMachineExecutor: Sendable {
  private struct State {
    var runLoop: CFRunLoop?
    var source: CFRunLoopSource?
    var runningThread: Thread?
  }

  private let createVirtualMachine: @Sendable () -> JSVirtualMachine
  private let state = Lock<State>(State())

  public var isRunning: Bool {
    self.state.withLock { $0.runLoop != nil }
  }

  public init(
    createVirtualMachine: @escaping @Sendable () -> JSVirtualMachine = { JSVirtualMachine() }
  ) {
    self.createVirtualMachine = createVirtualMachine
  }

  deinit {
    self.stop()
  }

  public func runBlocking() {
    self.state.withLock { state in
      state.runLoop = CFRunLoopGetCurrent()
      state.source = CFRunLoopCreateEmptySource()
      state.runningThread = .current
      JSVirtualMachine.threadLocal = self.createVirtualMachine()
      CFRunLoopAddSource(state.runLoop, state.source, .defaultMode)
    }
    CFRunLoopRun()
  }

  public func run() async throws {
    let box = Lock<UnsafeContinuation<Void, any Error>?>(nil)
    return try await withTaskCancellationHandler {
      try await withUnsafeThrowingContinuation { continuation in
        let isCancelled = box.withLock {
          guard !Task.isCancelled else { return true }
          $0 = continuation
          return false
        }
        guard !isCancelled else {
          return continuation.resume(throwing: CancellationError())
        }
        Thread.detachNewThread {
          self.runBlocking()
          box.withLock {
            $0?.resume()
            $0 = nil
          }
        }
      }
    } onCancel: {
      self.stop()
      box.withLock {
        $0?.resume(throwing: CancellationError())
        $0 = nil
      }
    }
  }

  public func stop() {
    self.state.withLock { state in
      guard let runLoop = state.runLoop, let source = state.source else { return }
      CFRunLoopRemoveSource(runLoop, source, .defaultMode)
      CFRunLoopStop(runLoop)
      state.runLoop = nil
      state.source = nil
      state.runningThread = nil
    }
  }

  public func withVirtualMachine<T, E: Error>(
    perform operation: @escaping @Sendable (JSVirtualMachine) throws(E) -> sending T
  ) async throws(E) -> sending T {
    let result = await withUnsafeContinuation {
      (continuation: UnsafeContinuation<Result<T, E>, Never>) in
      self.schedule {
        let result = Result { () throws(E) -> sending T in
          try operation(JSVirtualMachine.threadLocal!)
        }
        continuation.resume(returning: result)
      }
    }
    return try result.get()
  }

  public func withVirtualMachineIfAvailable<T, E: Error>(
    perform operation: (JSVirtualMachine) throws(E) -> T
  ) throws(E) -> T? {
    try self.state.withLock { state throws(E) in
      guard let vm = JSVirtualMachine.threadLocal, state.runningThread == .current else {
        return nil
      }
      return try operation(vm)
    }
  }

  private func schedule(_ work: @escaping @Sendable () -> Void) {
    self.state.withLock { state in
      guard let runLoop = state.runLoop else { executorNotRunning() }
      CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, work)
      CFRunLoopWakeUp(runLoop)
    }
  }
}

// MARK: - SerialExecutor

extension JSVirtualMachineExecutor: SerialExecutor {
  public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
    UnownedSerialExecutor(ordinary: self)
  }

  public func enqueue(_ job: UnownedJob) {
    self.schedule { job.runSynchronously(on: self.asUnownedSerialExecutor()) }
  }
}

// MARK: - TaskExecutor

@available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
extension JSVirtualMachineExecutor: TaskExecutor {
  public func asUnownedTaskExecutor() -> UnownedTaskExecutor {
    UnownedTaskExecutor(ordinary: self)
  }
}

// MARK: - Helpers

func executorNotRunning() -> Never {
  fatalError("Executor is not running. Call `run` or `runBlocking` to start it.")
}

private func CFRunLoopCreateEmptySource() -> CFRunLoopSource {
  var sourceContext = CFRunLoopSourceContext(
    version: 0,
    info: nil,
    retain: nil,
    release: nil,
    copyDescription: nil,
    equal: nil,
    hash: nil,
    schedule: { _, _, _ in },
    cancel: { _, _, _ in },
    perform: { _ in }
  )
  return CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &sourceContext)!
}
