import JavaScriptCoreExtras
import Testing

@Suite("Lock tests")
struct LockTests {
  @Test("Lock Releases Its Value When Destroyed")
  func lockReleasesValue() {
    weak var weakValue: TrackedValue?
    do {
      let value = TrackedValue()
      weakValue = value
      let lock = Lock(value)
      lock.withLock { _ in }
    }
    #expect(weakValue == nil)
  }

  @Test("RecursiveLock Releases Its Value When Destroyed")
  func recursiveLockReleasesValue() {
    weak var weakValue: TrackedValue?
    do {
      let value = TrackedValue()
      weakValue = value
      let lock = RecursiveLock(value)
      lock.withLock { _ in }
    }
    #expect(weakValue == nil)
  }
}

private final class TrackedValue: Sendable {}
