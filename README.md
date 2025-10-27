# JavaScriptCoreExtras

[![CI](https://github.com/mhayes853/javascript-core-extras/actions/workflows/ci.yml/badge.svg)](https://github.com/mhayes853/javascript-core-extras/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmhayes853%2Fjavascript-core-extras%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mhayes853/javascript-core-extras)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmhayes853%2Fjavascript-core-extras%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mhayes853/javascript-core-extras)

Additions to Apple's JavaScriptCore framework.

## Overview

JavaScriptCore is a great framework for allowing extensibility in your apps, at least if your users are technically inclined, as users can extend your app’s functionality with Javascript. This works well, but there’s quite a few problems:
- The framework provides no implementation for many common JavaScript APIs including `console.log` and `fetch`.
- Usage with Swift Concurrency is ambiguous, and is easy to get wrong.
- Converting between pure Swift types and `JSValue` instances can be tedious and error prone.

This package provides:
- Implementations of many common JavaScript APIs including `console.log`, `fetch`, with more advanced JavaScript APIs to come in the future.
- A universal mechanism for installing JavaScript into a `JSContext` through the `JSContextInstallable` protocol.
- A proper integration with Swift Concurrency through `JSActor`, `JSGlobalActor`, `JSVirtualMachineExecutor`, and `JSVirtualMachineExecutorPool`.
- Support for converting Codable types to and from `JSValue` instances.
- Type-safe functions through `JSFunctionValue`.

### Concurrency

You can execute JavaScript in the background with Swift Concurrency by ensuring that all `JSContext` and `JSValue` instances you create are isolated to `@JSGlobalActor`. The global actor schedules work on a dedicated thread for executing JavaScript.

```swift
@JSGlobalActor
class JavaScriptRuntime {
  var context = JSContext(virtualMachine: JSGlobalActor.virtualMachine)!

  func execute(_ code: String) {
    context.evaluateScript(code)
  }
}
```

However, this won't let you execute JavaScript concurrently on different `JSContext` instances in the background. To execute JavaScript concurrently in the background, you can use `JSVirtualMachineExecutorPool` to manage an object pool of `JSVirtualMachineExecutor` instances. Then, you can create `JSActor` instances with an executor to isolate a specific value to a thread that can execute JavaScript.

```swift
let pool = JSVirtualMachineExecutorPool(count: 4)
let executor = await pool.executor()

// An actor that safely isolates a JSContext.

let contextActor: JSActor<JSContext> = await executor.contextActor()

await contextActor.withIsolation { @Sendable contextActor in
  _ = contextActor.value.evaluateScript("console.log('Hello, World!')")
}

// JSActor allows you to isolate any value you specify to a thread with an active JSVirtualMachine.

struct JSIsolatedPayload {
  let a: String
  let b: Int
}

let payloadActor = JSActor(JSIsolatedPayload(a: "Hello", b: 42), executor: executor)
```

`JSVirtualMachineExecutor` also conforms to `TaskExecutor`, which means that you can use it as an executor preference for a task.

```swift
let pool = JSVirtualMachineExecutorPool(count: 4)
let executor = await pool.executor()

Task(executorPreference: executor) {
  print(JSVirtualMachineExecutor.current() === executor) // true
}
```

### Type-Safe Functions

You can create functions that are type-safe provided that the arguments and return value conform to `JSValueConvertible`.

```swift
// Codable values get a synthesized implementation to JSValueConvertible.
struct ReturnValue: Codable, JSValueConvertible {
  let a: String
  let b: Date
}

let context = JSContext()!

// Returns a JavaScript object with fields `a` and `b`.
context.setFunction(forKey: "produce", Int.self, String.self) {
  ReturnValue(a: "Hello \($1)", b: Date() + TimeInterval($0))
}

let value = context.evaluateScript("produce(10, 'blob')")
let returnValue = try ReturnValue(jsValue: value)
```

### Console Logging

You can add the console logger functions to a `JSContext` via:
```swift
let context = JSContext()!
try context.install([.consoleLogging])
```
This will install `console.log`, `console.trace`, `console.debug`, `console.info`, `console.warn`, and `console.error` to the `JSContext`. When calling those functions in Javascript, you’ll see detailed log messages in standard output.

Additionally, you can customize the logging destination via the `JSConsoleLogging` protocol. For instance, you may want to log messages to a `swift-log` logger.
```swift
import Logging

struct SwiftLogLogger: JSConsoleLogger {
  let logger: Logger

  func log(level: JSConsoleLoggerLevel?, message: String) {
    self.logger.log(level: level?.swiftLogLevel ?? .info, "\(message)")
  }
}

extension JSConsoleLoggerLevel {
  fileprivate var swiftLogLevel: Logger.Level {
    switch self {
    case .debug: .debug
    case .error: .error
    case .info: .info
    case .trace: .trace
    case .warn: .warning
    }
  }
}
```
Then, you can install `SwiftLogLogger` to your `JSContext` to redirect `console.log` calls to your logger.
```swift
let context = JSContext()!
try context.install([SwiftLogLogger(logger: logger)])
```

### Fetch

You can add Javascript’s `fetch` function to a `JSContext` like so.
```swift
let context = JSContext()!
try context.install([.fetch])
```
Since `fetch` depends on many Javascript classes, implementations of those classes will also be installed to the context alongside `fetch`. Those classes include `AbortController`, `AbortSignal`, `FormData`, `Headers`, `DOMException`, `Request`, `Response`, `Blob`, and `File`. At the time of writing this, `ReadableStream` is not supported.

You can also configure a `URLSession` instance to use as the underlying driver of the fetch implementation like so.
```swift
let context = JSContext()!

let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [MyURLProtocol.self]
let session = URLSession(configuration: configuration)

try context.install([.fetch(session: session)])
```
> 📱 `fetch(session:)` is only available on iOS 15+ because the fetch implementation uses data task specific delegates under the hood. On older versions, you can use `fetch(sessionConfiguration:)` where `sessionConfiguration` is a `URLSessionConfiguration`.

### JSContextInstallable

The previous examples show how to easily add Javascript code to a `JSContext`, and this functionality is brought to you by the `JSContextInstallable` protocol. You can conform a type to the protocol to specify how specific Javascript code should be added to a context.
```swift
struct MyInstaller: JSContextInstallable {
  func install(in context: JSContext) {
    let myFunction: @convention(block) () -> Void = {
      // ...
    }
    context.setObject(myFunction, forPath: "myFunction")
  }
}

extension JSContextInstallable where Self == MyInstaller {
  static var myFunction: Self { MyInstaller() }
}

let context = JSContext()!
try context.install([.consoleLogging, .fetch, .myFunction])
```
You can also install Javascript files from a `Bundle` or from the file system using the following.
```swift
let context = JSContext()!
try context.install([
  .bundled(path: "myBundledFile.js"), // Installs from main bundle.
  .bundled(path: "anotherBundledFile.js", in: .module),
  .file(at: URL.documentsDirectory.appending("myFile.js")),
  .files(at: [
    URL.documentsDirectory.appending("someFile.js"),
    URL.documentsDirectory.appending("otherFile.js")
  ])
])
```

## Documentation

The documentation for releases and main are available here.
* [main](https://swiftpackageindex.com/mhayes853/javascript-core-extras/main/documentation/javascriptcoreextras/)
* [0.x.x](https://swiftpackageindex.com/mhayes853/javascript-core-extras/~/documentation/javascriptcoreextras/)

## Installation

You can add JavaScriptCore Extras to an Xcode project by adding it to your project as a package.

> [https://github.com/mhayes853/javascript-core-extras](https://github.com/mhayes853/javascript-core-extras)

If you want to use JavaScriptCore Extras in a [SwiftPM](https://swift.org/package-manager/) project, it’s as simple as adding it to your `Package.swift`:

```swift
dependencies: [
  .package(
    url: "https://github.com/mhayes853/javascript-core-extras",
    branch: "main"
  ),
]
```

## License

This library is licensed under an MIT License. See [LICENSE](https://github.com/mhayes853/javascript-core-extras/blob/main/LICENSE) for details.
