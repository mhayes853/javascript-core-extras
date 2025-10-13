import JavaScriptCoreExtras

private let pool = JSVirtualMachineExecutorPool(count: 4)

func withContextActor<T: Sendable>(
  operation: @Sendable (isolated JSActor<JSContext>) async throws -> T
) async throws -> T {
  let executor = await pool.executor()
  defer { pool.release(executor: executor) }
  let contextActor = await executor.contextActor()
  return try await contextActor.withIsolation { @Sendable in
    try await operation($0)
  }
}
