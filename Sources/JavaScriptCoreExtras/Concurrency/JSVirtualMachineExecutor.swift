import Foundation
import JavaScriptCore

public final class JSVirtualMachineExecutor: Sendable, SerialExecutor {
  private let createVirtualMachine: @Sendable () -> JSVirtualMachine
  private let runLoop = Lock<CFRunLoop?>(nil)

  public init(
    createVirtualMachine: @escaping @Sendable () -> JSVirtualMachine = { JSVirtualMachine() }
  ) {
    self.createVirtualMachine = createVirtualMachine
  }

  deinit {
    self.stop()
  }

  public func runBlocking() {
    self.runLoop.withLock { runLoop in
      runLoop = CFRunLoopGetCurrent()
      let source = CFRunLoopCreateEmptySource()
      JSVirtualMachine.threadLocal = self.createVirtualMachine()
      CFRunLoopAddSource(runLoop, source, .defaultMode)
    }
    CFRunLoopRun()
  }

  public func run() async {
    await withUnsafeContinuation { continuation in
      Thread.detachNewThread {
        self.runBlocking()
        continuation.resume()
      }
    }
  }

  public func stop() {
    self.runLoop.withLock {
      guard let runLoop = $0 else { return }
      CFRunLoopStop(runLoop)
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

  public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
    UnownedSerialExecutor(ordinary: self)
  }

  public func enqueue(_ job: UnownedJob) {
    self.schedule { job.runSynchronously(on: self.asUnownedSerialExecutor()) }
  }

  private func schedule(_ work: @escaping @Sendable () -> Void) {
    self.runLoop.withLock { runLoop in
      guard let runLoop else { executorNotRunning() }
      CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, work)
      CFRunLoopWakeUp(runLoop)
    }
  }
}

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
