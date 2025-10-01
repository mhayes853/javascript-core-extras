import Foundation
import JavaScriptCore

// MARK: - JSVirtualMachineExecutor

public final class JSVirtualMachineExecutor: Sendable {
  private let createVirtualMachine: @Sendable () -> JSVirtualMachine
  private let runner = RecursiveLock<Runner?>(nil)

  public init(
    createVirtualMachine: @escaping @Sendable () -> JSVirtualMachine = { JSVirtualMachine() }
  ) {
    self.createVirtualMachine = createVirtualMachine
  }

  deinit {
    self.stop()
  }
}

// MARK: - Current

extension JSVirtualMachineExecutor {
  public static func current() -> JSVirtualMachineExecutor? {
    Self.threadLocal?.value
  }

  private static let threadLocalKey = "__jsCoreExtrasThreadLocalVirtualMachineExecutor__"

  private static var threadLocal: WeakBox<JSVirtualMachineExecutor>? {
    get {
      Thread.current.threadDictionary[Self.threadLocalKey] as? WeakBox<JSVirtualMachineExecutor>
    }
    set {
      Thread.current.threadDictionary[Self.threadLocalKey] = newValue
    }
  }
}

// MARK: - Running

extension JSVirtualMachineExecutor {
  public var isRunning: Bool {
    self.runner.withLock { $0 != nil }
  }

  public func runBlocking() {
    self.runner.withLock {
      $0 = Runner()
      Self.threadLocal = WeakBox(value: self)
      JSVirtualMachine.threadLocal = self.createVirtualMachine()
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
    self.runner.withLock { runner in
      runner?.stop()
      runner = nil
      Self.threadLocal = nil
      JSVirtualMachine.threadLocal = nil
    }
  }
}

// MARK: - VirtualMachine Access

extension JSVirtualMachineExecutor {
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
    try self.runner.withLock { runner throws(E) in
      guard let runner else { executorNotRunning() }
      guard let vm = JSVirtualMachine.threadLocal, runner.runningThread == .current else {
        return nil
      }
      return try operation(vm)
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

  private func schedule(_ work: @escaping @Sendable () -> Void) {
    self.runner.withLock { runner in
      guard let runner else { executorNotRunning() }
      runner.schedule(work)
    }
  }
}

// MARK: - TaskExecutor

@available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
extension JSVirtualMachineExecutor: TaskExecutor {
  public func asUnownedTaskExecutor() -> UnownedTaskExecutor {
    UnownedTaskExecutor(ordinary: self)
  }
}

// MARK: - Runnner

extension JSVirtualMachineExecutor {
  private final class Runner {
    private let runLoop: CFRunLoop
    private let source: CFRunLoopSource
    let runningThread: Thread

    init() {
      self.runLoop = CFRunLoopGetCurrent()
      self.source = CFRunLoopCreateEmptySource()
      self.runningThread = .current
      CFRunLoopAddSource(self.runLoop, self.source, .defaultMode)
    }

    func stop() {
      CFRunLoopRemoveSource(self.runLoop, self.source, .defaultMode)
      CFRunLoopStop(self.runLoop)
    }

    func schedule(_ work: @escaping @Sendable () -> Void) {
      CFRunLoopPerformBlock(self.runLoop, CFRunLoopMode.defaultMode.rawValue, work)
      CFRunLoopWakeUp(self.runLoop)
    }
  }
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

// MARK: - Helpers

func executorNotRunning() -> Never {
  fatalError("Executor is not running. Call `run` or `runBlocking` to start it.")
}
