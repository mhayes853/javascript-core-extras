import JavaScriptCoreExtras

final class TestLogger: JSConsoleLogger {
  private var _messages = Lock([LogMessage]())
  private let logger = PrintJSConsoleLogger()

  var messages: [LogMessage] {
    self._messages.withLock { $0 }
  }

  func log(level: JSConsoleLoggerLevel?, message: String) {
    self.logger.log(level: level, message: message)
    self._messages.withLock { $0.append(LogMessage(level: level, message: message)) }
  }
}

struct LogMessage: Hashable, Sendable {
  let level: JSConsoleLoggerLevel?
  let message: String
}
