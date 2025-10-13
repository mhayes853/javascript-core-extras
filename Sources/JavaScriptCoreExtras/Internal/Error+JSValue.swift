import Foundation
import JavaScriptCore

extension Error {
  func _jsValue(in context: JSContext) -> JSValue {
    if let convertible = self as? any ConvertibleToJSValue,
      let value = try? convertible.jsValue(in: context)
    {
      return value
    } else {
      return JSValue(newErrorFromMessage: self.localizedDescription, in: context)
    }
  }
}

func tryOperation<T: ConvertibleToJSValue>(
  in context: JSContext,
  _ operation: () throws -> T
) -> JSValue {
  do {
    return try operation().jsValue(in: context)
  } catch {
    context.exception = error._jsValue(in: context)
    return JSValue(undefinedIn: context)
  }
}
