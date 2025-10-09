import Foundation
@preconcurrency import JavaScriptCore

// MARK: - JSVirtualMachineExecutor

/// An `Executor` that runs operations on the same thread that a `JSVirtualMachine` was created on.
///
/// Before attempting to run work on this executor, make sure to call ``runBlocking()`` or
/// ``run()`` first. This will ensure that an active thread is running with a virtual machine
/// present.
///
/// Alternatively, if this executor instance was obtained from calling
/// ``JSVirtualMachineExecutorPool/executor()`` then the instance will already be running.
///
/// You can use this class to ensure thread safe access to `JSContext` or `JSValue` instances with
/// ``JSActor``.
/// ```swift
/// @preconcurrency import JavaScriptCore
///
/// func setupAsyncWork(in executor: JSVirtualMachineExecutor) {
///   executor.withVirtualMachineIfCurrentExecutor { vm in
///     let context = JSContext(virtualMachine: vm)
///     let myAsyncWork: @convention(block) (JSValue) -> Void = { value in
///       let valueActor = JSActor(value, executor: executor)
///       Task {
///         try await asyncWork()
///         _ = await valueActor.withIsolation { @Sendable in
///           // Runs on the same thread as the underlying virtual machine.
///           $0.value.invokeMethod("onCompleted", withArguments: [])
///         }
///       }
///     }
///     context?.setObject(myAsyncWork, forPath: "myAsyncWork")
///   }
/// }
///
/// private func asyncWork() async throws {
///   // ...
/// }
/// ```
/// > Notice: You will need the preconcurrency import to avoid compiler errors related to
/// > sending non-Sendable `JSValue` or `JSContext` instances. This is safe as long as the
/// > `JSValue` or `JSContext` is tied to the same `JSVirtualMachine` as the executor.
public final class JSVirtualMachineExecutor: Sendable {
  private let createVirtualMachine: @Sendable () -> JSVirtualMachine
  private let runner = RecursiveLock<Runner?>(nil)
  
  /// Creates an executor.
  ///
  /// - Parameter createVirtualMachine: A factory closure to create a `JSVirtualMachine` when
  ///   ``run()`` or ``runBlocking()`` are called.
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
  /// Returns the current running ``JSVirtualMachineExecutor`` on the current thread.
  ///
  /// - Returns: An executor if one is running on the current thread.
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
  /// Whether or not this executor is running.
  public var isRunning: Bool {
    self.runner.withLock { $0 != nil }
  }

  /// Begins running this executor.
  ///
  /// > Warning: This will indefinitely block the current thread of execution until ``stop()`` is
  /// > explicitly called. Use ``run()`` if you do not want to block the current thread.
  public func runBlocking() {
    self.runner.withLock {
      $0 = Runner()
      Self.threadLocal = WeakBox(value: self)
      JSVirtualMachine.threadLocal = self.createVirtualMachine()
    }
    CFRunLoopRun()
  }
  
  /// Begins running this executor.
  ///
  /// This method creates a new dedicated thread with a run loop to schedule and execute work.
  ///
  /// > Notice: This will suspend the current task indefinitely until ``stop()`` is called or when
  /// > the task is cancelled.
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
        Thread.detachNewThread { [weak self] in
          self?.runBlocking()
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
  
  /// Stops running this executor.
  public func stop() {
    self.runner.withLock { runner in
      runner?.stop()
      runner = nil
      Self.threadLocal = nil
      JSVirtualMachine.threadLocal = nil
    }
  }
}

// MARK: - JSContextActor Creation

extension JSVirtualMachineExecutor {
  /// Returns a ``JSActor`` with a new `JSContext` created with the `JSVirtualMachine` held by
  /// this executor.
  ///
  /// This executor must be running.
  ///
  /// - Returns: A ``JSActor`` isolating a new `JSContext`.
  public func contextActor() async -> JSActor<JSContext> {
    await self.withVirtualMachine { vm in
      JSActor(JSContext(virtualMachine: vm), executor: self)
    }
  }

  /// Synchronously returns a ``JSActor`` with a new `JSContext` created with the
  /// `JSVirtualMachine` held by this executor if this executor is equivalent to the executor
  /// returned from ``current()``.
  ///
  /// Nil is returned if this executor is running, but is not the current executor.
  ///
  /// This executor must be running.
  ///
  /// - Returns: A ``JSActor`` isolating a new `JSContext`, or nil if this executor is not the
  ///   current executor.
  public func contextActorIfCurrentExecutor() -> JSActor<JSContext>? {
    self.withVirtualMachineIfCurrentExecutor { vm in
      JSActor(JSContext(virtualMachine: vm), executor: self)
    }
  }
}

// MARK: - VirtualMachine Access

extension JSVirtualMachineExecutor {
  /// Asynchronously accesses the `JSVirtualMachine` of this executor.
  ///
  /// This executor must be running.
  ///
  /// - Parameter operation: An operation to perform with the virtual machine.
  /// - Returns: The result of the operation.
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
  
  /// Synchronously accesses the `JSVirtualMachine` of this executor if this current executor is
  /// equivalent to the executor returned from ``current()``.
  ///
  /// Nil is returned if this executor is running, but is not the current executor.
  ///
  /// This executor must be running.
  ///
  /// - Parameter operation: An operation to perform with the virtual machine.
  /// - Returns: The result of the operation, or nil if this executor is not the current executor.
  public func withVirtualMachineIfCurrentExecutor<T, E: Error>(
    perform operation: (JSVirtualMachine) throws(E) -> T
  ) throws(E) -> T? {
    try self.runner.withLock { runner throws(E) in
      guard runner != nil else { executorNotRunning() }
      guard
        let vm = JSVirtualMachine.threadLocal,
        self === JSVirtualMachineExecutor.current()
      else {
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

private func executorNotRunning() -> Never {
  fatalError(
    """
    JSVirtualMachineExecutor is not running. Call `run` or `runBlocking` to start it.
    
    If the executor was obtained from a JSVirtualMachineExecutorPool, ensure it hasn't been \ 
    garbage collected.
    """
  )
}
