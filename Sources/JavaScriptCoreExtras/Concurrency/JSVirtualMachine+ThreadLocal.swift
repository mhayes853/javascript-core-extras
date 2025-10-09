import Foundation

extension JSVirtualMachine {
  private static let key = "__jsCoreExtrasThreadLocalVirtualMachine__"

  static var threadLocal: JSVirtualMachine? {
    get { Thread.current.threadDictionary[key] as? JSVirtualMachine }
    set { Thread.current.threadDictionary[key] = newValue }
  }
}
