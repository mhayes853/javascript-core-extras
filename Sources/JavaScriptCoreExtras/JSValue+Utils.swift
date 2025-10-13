import JavaScriptCore

// MARK: - Is Iterable

extension JSValue {
  /// Whether or not this value is iterable.
  public var isIterable: Bool {
    #if !os(tvOS)
      self.hasProperty(self.context.evaluateScript("Symbol.iterator"))
    #else
      var obj = self.context.objectForKeyedSubscript("_jsCoreExtrasIsIterable")
      if obj == nil || obj?.isUndefined == true {
        self.context.installIsIterable()
        obj = self.context.objectForKeyedSubscript("_jsCoreExtrasIsIterable")
      }
      return obj?.call(withArguments: [self]).toBool() ?? false
    #endif
  }
}

extension JSContext {
  fileprivate func installIsIterable() {
    self.evaluateScript(
      """
      function _jsCoreExtrasIsIterable(obj) {
        return !!obj[Symbol.iterator];
      }
      """
    )
  }
}

// MARK: - Is Instance

extension JSValue {
  /// Returns true if this value is an instance of the specified class name.
  ///
  /// - Parameter className: The name of the class.
  public func isInstanceOf(className: String) -> Bool {
    self.context.objectForKeyedSubscript(className).map { self.isInstance(of: $0) } ?? false
  }
}
