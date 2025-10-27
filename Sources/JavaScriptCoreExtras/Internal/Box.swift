final class WeakBox<Value: AnyObject> {
  weak var value: Value?

  init(value: Value?) {
    self.value = value
  }
}

final class MutableBox<Value> {
  var value: Value

  init(value: Value) {
    self.value = value
  }
}
