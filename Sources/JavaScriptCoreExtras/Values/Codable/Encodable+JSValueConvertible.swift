import JavaScriptCore

// MARK: - Encodable

extension Encodable where Self: ConvertibleToJSValue {
  public func jsValue(in context: JSContext) throws -> JSValue {
    try JSEncoder(context: context).encode(self)
  }
}

// MARK: - JSEncoder

private final class JSEncoder {
  let context: JSContext
  var codingPath = [CodingKey]()
  var userInfo = [CodingUserInfoKey: Any]()

  init(context: JSContext) {
    self.context = context
  }

  func encode<T: Encodable>(_ value: T) throws -> JSValue {
    let box = Box()
    let encoder = _ContainerEncoder(
      context: context,
      codingPath: self.codingPath,
      userInfo: self.userInfo,
      assign: { box.value = $0 }
    )
    try value.encode(to: encoder)
    return box.value!
  }
}

extension JSEncoder {
  private final class _ContainerEncoder: Encoder {
    let context: JSContext
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    private let assign: (JSValue) -> Void

    init(
      context: JSContext,
      codingPath: [CodingKey],
      userInfo: [CodingUserInfoKey: Any],
      assign: @escaping (JSValue) -> Void
    ) {
      self.context = context
      self.codingPath = codingPath
      self.userInfo = userInfo
      self.assign = assign
    }

    func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
      let obj = JSValue(newObjectIn: context)!
      self.assign(obj)
      let c = KeyedContainer<Key>(
        context: self.context,
        object: obj,
        codingPath: self.codingPath,
        userInfo: self.userInfo
      )
      return KeyedEncodingContainer(c)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
      let arr = JSValue(newArrayIn: self.context)!
      self.assign(arr)
      return UnkeyedContainer(
        context: self.context,
        array: arr,
        codingPath: self.codingPath,
        userInfo: self.userInfo
      )
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
      SingleContainer(context: self.context, assign: self.assign)
    }
  }
}

extension JSEncoder {
  private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let context: JSContext
    let object: JSValue
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]

    func encodeNil(forKey key: Key) throws {
      let null = JSValue(nullIn: self.context)
      self.object.setObject(null, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: Bool, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: String, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: Double, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: Float, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: Int, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: Int8, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: Int16, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: Int32, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: Int64, forKey key: Key) throws {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        let v = value.jsValue(in: self.context)
        self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    func encode(_ value: UInt, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: UInt8, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: UInt16, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: UInt32, forKey key: Key) throws {
      let v = value.jsValue(in: self.context)
      self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
    }

    func encode(_ value: UInt64, forKey key: Key) throws {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        let v = value.jsValue(in: self.context)
        self.object.setObject(v, forKeyedSubscript: key.stringValue as NSString)
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
      let nested = try value.convertedJSValue(in: self.context)
      self.object.setObject(nested, forKeyedSubscript: key.stringValue as NSString)
    }

    func nestedContainer<NestedKey>(
      keyedBy: NestedKey.Type,
      forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
      let obj = JSValue(newObjectIn: context)!
      self.object.setObject(obj, forKeyedSubscript: key.stringValue as NSString)
      let c = KeyedContainer<NestedKey>(
        context: self.context,
        object: obj,
        codingPath: self.codingPath + [key],
        userInfo: self.userInfo
      )
      return KeyedEncodingContainer(c)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
      let arr = JSValue(newArrayIn: self.context)!
      self.object.setObject(arr, forKeyedSubscript: key.stringValue as NSString)
      return UnkeyedContainer(
        context: self.context,
        array: arr,
        codingPath: self.codingPath + [key],
        userInfo: self.userInfo
      )
    }

    func superEncoder() -> Encoder {
      _ContainerEncoder(
        context: self.context,
        codingPath: self.codingPath + [SuperCodingKey()],
        userInfo: self.userInfo,
        assign: { self.object.setObject($0, forKeyedSubscript: "super") }
      )
    }

    func superEncoder(forKey key: Key) -> Encoder {
      _ContainerEncoder(
        context: self.context,
        codingPath: self.codingPath + [SuperCodingKey()],
        userInfo: self.userInfo,
        assign: { self.object.setObject($0, forKeyedSubscript: key.stringValue as NSString) }
      )
    }
  }
}

extension JSEncoder {
  private struct UnkeyedContainer: UnkeyedEncodingContainer {
    let context: JSContext
    let array: JSValue
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var count = 0

    mutating func encodeNil() throws {
      self.array.setObject(JSValue(nullIn: self.context), atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: Bool) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: String) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: Double) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: Float) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: Int) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: Int8) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: Int16) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: Int32) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: Int64) throws {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        let v = value.jsValue(in: self.context)
        self.array.setObject(v, atIndexedSubscript: self.count)
        self.count += 1
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    mutating func encode(_ value: UInt) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: UInt8) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: UInt16) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: UInt32) throws {
      let v = value.jsValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func encode(_ value: UInt64) throws {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        let v = value.jsValue(in: self.context)
        self.array.setObject(v, atIndexedSubscript: self.count)
        self.count += 1
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
      let v = try value.convertedJSValue(in: self.context)
      self.array.setObject(v, atIndexedSubscript: self.count)
      self.count += 1
    }

    mutating func nestedContainer<NestedKey>(
      keyedBy: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
      let obj = JSValue(newObjectIn: context)!
      self.array.setObject(obj, atIndexedSubscript: self.count)
      self.count += 1
      let c = KeyedContainer<NestedKey>(
        context: self.context,
        object: obj,
        codingPath: self.codingPath,
        userInfo: self.userInfo
      )
      return KeyedEncodingContainer(c)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
      let arr = JSValue(newArrayIn: context)!
      self.array.setObject(arr, atIndexedSubscript: self.count)
      self.count += 1
      return UnkeyedContainer(
        context: self.context,
        array: arr,
        codingPath: self.codingPath,
        userInfo: self.userInfo
      )
    }

    mutating func superEncoder() -> Encoder {
      let index = self.count
      self.count += 1
      return _ContainerEncoder(
        context: self.context,
        codingPath: self.codingPath + [SuperCodingKey()],
        userInfo: self.userInfo,
        assign: { [self] in self.array.setObject($0, atIndexedSubscript: index) }
      )
    }
  }
}

extension JSEncoder {
  private struct SingleContainer: SingleValueEncodingContainer {
    let context: JSContext
    let assign: (JSValue) -> Void
    var codingPath = [CodingKey]()

    mutating func encodeNil() throws {
      self.assign(JSValue(nullIn: context))
    }

    mutating func encode(_ value: Bool) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: String) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: Double) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: Float) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: Int) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: Int8) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: Int16) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: Int32) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: Int64) throws {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        self.assign(value.jsValue(in: self.context))
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    mutating func encode(_ value: UInt) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: UInt8) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: UInt16) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: UInt32) throws {
      self.assign(value.jsValue(in: self.context))
    }

    mutating func encode(_ value: UInt64) throws {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        self.assign(value.jsValue(in: self.context))
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
      self.assign(try value.convertedJSValue(in: self.context))
    }
  }
}

extension JSEncoder {
  private struct SuperCodingKey: CodingKey {
    static let string = "super"
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
    init() { self.stringValue = Self.string }
  }
}

extension JSEncoder {
  private final class Box {
    var value: JSValue?
  }
}

// MARK: - Helpers

extension Encodable {
  fileprivate func convertedJSValue(in context: JSContext) throws -> JSValue {
    if let value = self as? any ConvertibleToJSValue {
      try value.jsValue(in: context)
    } else {
      try JSEncoder(context: context).encode(self)
    }
  }
}
