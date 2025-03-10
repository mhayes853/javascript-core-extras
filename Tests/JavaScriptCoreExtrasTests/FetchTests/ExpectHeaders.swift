import CustomDump
import JavaScriptCoreExtras

func expectHeaders(from value: JSValue?, toEqual headers: [[String]]) {
  var entries = [[String]]()
  let forEach: @convention(block) (JSValue) -> Void = { value in
    guard value.atIndex(0).isString && value.atIndex(1).isString else { return }
    entries.append([value.atIndex(0).toString(), value.atIndex(1).toString()])
  }
  value?.invokeMethod("forEach", withArguments: [unsafeBitCast(forEach, to: JSValue.self)])
  expectNoDifference(Set(entries), Set(headers))
}
