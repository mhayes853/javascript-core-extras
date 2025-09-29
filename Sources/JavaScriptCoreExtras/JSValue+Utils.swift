import JavaScriptCore

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
