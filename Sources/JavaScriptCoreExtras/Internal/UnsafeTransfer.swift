package struct UnsafeTransfer<Value>: @unchecked Sendable {
  package let value: Value

  package init(value: Value) {
    self.value = value
  }
}
