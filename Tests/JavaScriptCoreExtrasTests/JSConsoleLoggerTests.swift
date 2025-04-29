import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("JSConsoleLogger tests")
struct JSConsoleLoggerTests {
  private let context = JSContext()!
  private let logger = TestLogger()

  init() throws {
    try self.context.install([self.logger])
  }

  @Test("Basic String Log")
  func basicStringLog() {
    self.context.evaluateScript(
      """
      console.log("hello world")
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "hello world")])
  }

  @Test("Basic Number Log")
  func basicNumberLog() {
    self.context.evaluateScript(
      """
      console.log(1)
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "1")])
  }

  @Test("Basic Object Log")
  func basicObjectLog() {
    self.context.evaluateScript(
      """
      console.log({ a: { b: { c: {} } } })
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "{ a: { b: { c: {} } } }")]
    )
  }

  @Test("Basic Object With Constructor Log")
  func basicObjectWithConstructorLog() {
    self.context.evaluateScript(
      """
      console.log({ constructor: "hello" })
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "{ constructor: 'hello' }")]
    )
  }

  @Test("Basic Object With Constructor Object Log")
  func basicObjectWithConstructorObjectLog() {
    self.context.evaluateScript(
      """
      console.log({ constructor: { a: "world" } })
      """
    )
    #expect(
      self.logger.messages == [LogMessage(level: nil, message: "{ constructor: { a: 'world' } }")]
    )
  }

  @Test("Basic Numeric Object Log")
  func basicNumericObjectLog() {
    self.context.evaluateScript(
      """
      console.log({ a: { 1: { 2: {} } } })
      """
    )
    #expect(
      self.logger.messages == [LogMessage(level: nil, message: "{ a: { '1': { '2': {} } } }")]
    )
  }

  @Test("Basic Object Log toString")
  func basicObjectLogToString() {
    self.context.evaluateScript(
      """
      console.log({ a: { b: { c: {} } } }.toString())
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "[object Object]")])
  }

  @Test("Basic Function Log")
  func basicFunctionLog() {
    self.context.evaluateScript(
      """
      const foo = () => 1 + 1
      console.log(foo)
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "[Function: foo]")])
  }

  @Test("Basic Anonymous Function Log")
  func basicAnonymousFunctionLog() {
    self.context.evaluateScript(
      """
      console.log(() => 1 + 1)
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "[Function: (anonymous)]")]
    )
  }

  @Test("Basic Function toString Log")
  func basicFunctionToStringLog() {
    self.context.evaluateScript(
      """
      const foo = () => 1 + 1
      console.log(foo.toString())
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "() => 1 + 1")])
  }

  @Test("Basic Class Instance Log")
  func basicClassInstanceLog() {
    self.context.evaluateScript(
      """
      class X {
        bar
        foo() {}
      }
      console.log(new X())
      """
    )
    #expect(
      self.logger.messages == [LogMessage(level: nil, message: "class X { bar: undefined }")]
    )
  }

  @Test("Basic Class Private Instance Variable Log")
  func basicClassPrivateInstanceVariableLog() {
    self.context.evaluateScript(
      """
      class X {
        #bar
        foo() {}
      }
      console.log(new X())
      """
    )
    #expect(
      self.logger.messages == [LogMessage(level: nil, message: "class X {}")]
    )
  }

  @Test("Basic Class Constructor Log")
  func basicClassConstructorLog() {
    self.context.evaluateScript(
      """
      class X {
        bar
        foo() {}
      }
      console.log(X)
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "[class X]")])
  }

  @Test("Basic Nested Class Constructor Log")
  func basicNestedClassConstructorLog() {
    self.context.evaluateScript(
      """
      class Y {
        foo
      }
      class X {
        bar
        y
        foo() {}
      }
      const x = new X()
      x.y = new Y()
      x.bar = { a: "bar" }
      console.log(x)
      """
    )
    #expect(
      self.logger.messages == [
        LogMessage(
          level: nil,
          message: "class X { bar: { a: 'bar' }, y: class Y { foo: undefined } }"
        )
      ]
    )
  }

  @Test(
    "Basic Primitive Class Constructor Log",
    arguments: [
      "Set", "Array", "Map", "WeakSet", "Function", "Object", "Promise", "WeakMap", "Date"
    ]
  )
  func basicPrimitiveClassConstructorLog(name: String) {
    self.context.evaluateScript(
      """
      console.log(\(name))
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "[class \(name)]")])
  }

  @Test("Basic Class toString Log")
  func basicClassToStringLog() {
    self.context.evaluateScript(
      """
      class X {
        bar
        foo() {}
      }
      console.log(X.toString())
      """
    )
    let message = """
      class X {
        bar
        foo() {}
      }
      """
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: message)])
  }

  @Test("Basic Proxy Log")
  func basicProxyLog() {
    self.context.evaluateScript(
      """
      class X {
        bar
        foo() {}
      }
      console.log(new Proxy(new X(), () => new X()))
      """
    )
    #expect(
      self.logger.messages == [LogMessage(level: nil, message: "class X { bar: undefined }")]
    )
  }

  @Test("Basic Null Log")
  func basicNullLog() {
    self.context.evaluateScript(
      """
      console.log(null)
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "null")])
  }

  @Test("Basic Undefined Log")
  func basicUndefinedLog() {
    self.context.evaluateScript(
      """
      console.log(undefined)
      """
    )
    expectNoDifference(self.logger.messages, [LogMessage(level: nil, message: "undefined")])
  }

  @Test("Basic Array Log")
  func basicArrayLog() {
    self.context.evaluateScript(
      """
      console.log(["hello", 1, true, "world"])
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "[ 'hello', 1, true, 'world' ]")]
    )
  }

  @Test("Basic Empty Array Log")
  func basicEmptyArrayLog() {
    self.context.evaluateScript(
      """
      console.log([])
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "[]")]
    )
  }

  @Test("Basic Nested Array Log")
  func basicNestedArrayLog() {
    self.context.evaluateScript(
      """
      console.log(["hello", ["world"], { a: "world" }])
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "[ 'hello', [ 'world' ], { a: 'world' } ]")]
    )
  }

  @Test("Basic Set Log")
  func basicSetLog() {
    self.context.evaluateScript(
      """
      console.log(new Set([1, "hello", true]))
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "Set(3) { 1, 'hello', true }")]
    )
  }

  @Test("Basic Set Subclass Log")
  func basicSetSubclassLog() {
    self.context.evaluateScript(
      """
      class SubSet extends Set {}
      console.log(new SubSet([1, "hello", true]))
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "SubSet(3) { 1, 'hello', true }")]
    )
  }

  @Test("Basic Empty Set Log")
  func basicEmptySetLog() {
    self.context.evaluateScript(
      """
      console.log(new Set())
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "Set(0) {}")]
    )
  }

  @Test("Basic Map Log")
  func basicMapLog() {
    self.context.evaluateScript(
      """
      console.log(new Map([["foo", 2], ["bar", "baz"], [2, "abc"], [{ a: "p" }, true]]))
      """
    )
    expectNoDifference(
      self.logger.messages,
      [
        LogMessage(
          level: nil,
          message: "Map(4) { 'foo' => 2, 'bar' => 'baz', 2 => 'abc', { a: 'p' } => true }"
        )
      ]
    )
  }

  @Test("Basic Map Subclass Log")
  func basicMapSubclassLog() {
    self.context.evaluateScript(
      """
      class SubMap extends Map {}
      console.log(new SubMap([["foo", 2], ["bar", "baz"], [2, "abc"], [{ a: "p" }, true]]))
      """
    )
    expectNoDifference(
      self.logger.messages,
      [
        LogMessage(
          level: nil,
          message: "SubMap(4) { 'foo' => 2, 'bar' => 'baz', 2 => 'abc', { a: 'p' } => true }"
        )
      ]
    )
  }

  @Test("Basic Empty Map Log")
  func basicEmptyMapLog() {
    self.context.evaluateScript(
      """
      console.log(new Map())
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "Map(0) {}")]
    )
  }

  @Test("Basic Symbol Log")
  func basicSymbolLog() {
    self.context.evaluateScript(
      """
      console.log(Symbol.iterator)
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "Symbol")]
    )
  }

  @Test("Basic Date Log")
  func basicDateLog() {
    self.context.evaluateScript(
      """
      console.log(new Date("2024-11-14T00:00:00.000Z"))
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "2024-11-14T00:00:00.000Z")]
    )
  }

  @Test("Basic Variadic Args Log")
  func basicVariadicArgsLog() {
    self.context.evaluateScript(
      """
      console.log(1, "hello", true)
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "1 hello true")]
    )
  }

  @Test("Logs Undefined When No Args")
  func noArgs() {
    self.context.evaluateScript(
      """
      console.log()
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "undefined")]
    )
  }

  @Test("Format as Non-First Arg, Does Not Output Formatted Log")
  func formatNonFirst() {
    self.context.evaluateScript(
      """
      console.log(1, "hello %s", "world")
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "1 hello %s world")]
    )
  }

  @Test("Format String Args")
  func formatStringArgs() {
    self.context.evaluateScript(
      """
      console.log("hello %s %s %s", "world", 10, { a: "world" })
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello world 10 { a: 'world' }")]
    )
  }

  @Test("Format Adjacent String Args")
  func formatAdjacnetStringArgs() {
    self.context.evaluateScript(
      """
      console.log("hello %s %s%s", "world", 10, { a: "world" })
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello world 10{ a: 'world' }")]
    )
  }

  @Test("Format String Args, Not Enough Args")
  func formatStringNotEnoughArgs() {
    self.context.evaluateScript(
      """
      console.log("hello %s %s %s", "world", 10)
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello world 10 %s")]
    )
  }

  @Test("Format String Args, Too Many Args")
  func formatStringTooManyArgs() {
    self.context.evaluateScript(
      """
      console.log("hello %s %s %s", "world", 10, { a: "world" }, "test", 20)
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello world 10 { a: 'world' } test 20")]
    )
  }

  @Test("Format String Args, Does Not Replace %%s instances")
  func formatStringDoesNotReplace() {
    self.context.evaluateScript(
      """
      console.log("hello skjks%%%%%%sskj %%s", "world")
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello skjks%%%%%%sskj %%s world")]
    )
  }

  @Test("Format String Args With Mix of %%s")
  func formatMixStringArgs() {
    self.context.evaluateScript(
      """
      console.log("hello %%%s %s%s", "world", 10, { a: "world" })
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello %%%s world10 { a: 'world' }")]
    )
  }

  @Test("Format Integers")
  func formatIntegers() {
    self.context.evaluateScript(
      """
      console.log("hello %%d %%i %d %i %d %i %d %i", 10, 20, 10.298928, 20.208929, Infinity, "blob")
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello %%d %%i 10 20 10 20 Infinity NaN")]
    )
  }

  @Test("Format Floats")
  func formatFloats() {
    self.context.evaluateScript(
      """
      console.log("hello %%f %f %f %f %f %f %f", 10, 20, 10.298928, 20.208929, Infinity, "blob")
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello %%f 10 20 10.298928 20.208929 Infinity NaN")]
    )
  }

  @Test("Format DOM Element")
  func formatDomElement() {
    self.context.evaluateScript(
      """
      console.log("hello %%o %o %o %o", "test", 10, { a: "world" })
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello %%o 'test' 10 { a: 'world' }")]
    )
  }

  @Test("Format Object")
  func formatObject() {
    self.context.evaluateScript(
      """
      console.log("hello %%O %O %O %O", "test", 10, { a: "world" })
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello %%O 'test' 10 { a: 'world' }")]
    )
  }

  @Test("Removes %c Formats")
  func removesCSSFormats() {
    self.context.evaluateScript(
      """
      console.log("%c hello", "color:green;")
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: " hello")]
    )
  }

  @Test("Does Not Format Invalid Formatters")
  func invalidFormatters() {
    self.context.evaluateScript(
      """
      console.log("hello %z %@ %e", 10, 20, 30)
      """
    )
    expectNoDifference(
      self.logger.messages,
      [LogMessage(level: nil, message: "hello %z %@ %e 10 20 30")]
    )
  }

  @Test("All Formatters Combined")
  func allFormatters() {
    self.context.evaluateScript(
      """
      console.log("There are %d out of %f in the place of %O in %s", 10, 20.5, "Kansas", "Kansas", "yes")
      """
    )
    expectNoDifference(
      self.logger.messages,
      [
        LogMessage(
          level: nil,
          message: "There are 10 out of 20.5 in the place of 'Kansas' in Kansas yes"
        )
      ]
    )
  }

  @Test("Log With Levels")
  func withLevels() {
    self.context.evaluateScript(
      """
      console.log("Hello %s", "World")
      console.info("Hello %s", "World")
      console.error("Hello %s", "World")
      console.debug("Hello %s", "World")
      console.trace("Hello %s", "World")
      console.warn("Hello %s", "World")
      """
    )
    expectNoDifference(
      self.logger.messages,
      [
        LogMessage(level: nil, message: "Hello World"),
        LogMessage(level: .info, message: "Hello World"),
        LogMessage(level: .error, message: "Hello World"),
        LogMessage(level: .debug, message: "Hello World"),
        LogMessage(level: .trace, message: "Hello World"),
        LogMessage(level: .warn, message: "Hello World")
      ]
    )
  }

  @Test("Logs to Both Loggers of Combined Logger")
  func logsToCombinedLogger() throws {
    let logger1 = TestLogger()
    let logger2 = TestLogger()
    try self.context.install([combineJSConsoleLoggers([logger1, logger2])])
    self.context.evaluateScript(
      """
      console.log("Hello %s", "World")
      console.info("Hello %s", "World")
      console.error("Hello %s", "World")
      console.debug("Hello %s", "World")
      console.trace("Hello %s", "World")
      console.warn("Hello %s", "World")
      """
    )
    let expectedMessages = [
      LogMessage(level: nil, message: "Hello World"),
      LogMessage(level: .info, message: "Hello World"),
      LogMessage(level: .error, message: "Hello World"),
      LogMessage(level: .debug, message: "Hello World"),
      LogMessage(level: .trace, message: "Hello World"),
      LogMessage(level: .warn, message: "Hello World")
    ]
    expectNoDifference(logger1.messages, expectedMessages)
    expectNoDifference(logger2.messages, expectedMessages)
  }
}
