# JavaScriptCoreExtras

Extensions to Apple's JavaScriptCore framework.

## Overview

JavaScriptCore is a great framework for allowing extensibility in your apps, at least if your users are technically inclined, as users can extend your app’s functionality with Javascript. This works great, but there’s a problem: JavaScriptCore provides no implementation for many common Javascript functions including `console.log` and `fetch`.

This package provides implementations of both `console.log`, `fetch`, and much more to come in the future. It also provides a protocol that acts as a universal mechanism for adding functions and code to a `JSContext` called `JSContextInstallable`.

## Console Logging

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

## Fetch

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

## JSContextInstallable

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
