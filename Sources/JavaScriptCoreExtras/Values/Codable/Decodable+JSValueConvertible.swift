// MARK: - Decodable

extension Decodable where Self: ConvertibleFromJSValue {
  public init(jsValue: JSValue) throws {
    self = try JSDecoder().decode(Self.self, from: jsValue)
  }
}

// MARK: - JSDecoder

private final class JSDecoder {
  func decode<T: Decodable>(_ type: T.Type, from value: JSValue) throws -> T {
    try T(from: _ContainerDecoder(root: value))
  }
}

extension JSDecoder {
  private final class _ContainerDecoder: Decoder {
    let root: JSValue
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(root: JSValue) {
      self.root = root
    }

    func container<Key>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
      guard self.root.isObject && !self.root.isArray else { throw JSDecodingError.typeMismatch }
      return KeyedDecodingContainer(
        KeyedContainer<Key>(object: self.root, codingPath: self.codingPath)
      )
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
      guard self.root.isArray else { throw JSDecodingError.typeMismatch }
      return UnkeyedContainer(array: self.root, codingPath: self.codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
      SingleContainer(value: self.root, codingPath: self.codingPath)
    }
  }
}

extension JSDecoder {
  private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let object: JSValue
    var codingPath: [CodingKey]
    var allKeys: [Key] { [] }

    func contains(_ key: Key) -> Bool {
      self.object.hasProperty(key.stringValue)
    }

    func decodeNil(forKey key: Key) throws -> Bool {
      let value = try self.require(key)
      return value.isNull || value.isUndefined
    }

    func require(_ key: Key) throws -> JSValue {
      guard self.object.hasProperty(key.stringValue),
        let value = self.object.objectForKeyedSubscript(key.stringValue)
      else {
        throw JSDecodingError.missingKey
      }
      return value
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
      try Bool(jsValue: self.require(key))
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
      try String(jsValue: self.require(key))
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
      try Double(jsValue: self.require(key))
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
      try Int(jsValue: self.require(key))
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
      try Int8(jsValue: self.require(key))
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
      try Int16(jsValue: self.require(key))
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
      try Int32(jsValue: self.require(key))
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        try Int64(jsValue: self.require(key))
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
      try UInt(jsValue: self.require(key))
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
      try UInt8(jsValue: self.require(key))
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
      try UInt16(jsValue: self.require(key))
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
      try UInt32(jsValue: self.require(key))
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        try UInt64(jsValue: self.require(key))
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
      let jsValue = try self.require(key)
      if let converted = try T(convertingIfAble: jsValue) {
        return converted
      }
      return try JSDecoder().decode(T.self, from: jsValue)
    }

    func nestedContainer<NestedKey>(
      keyedBy: NestedKey.Type,
      forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
      try _ContainerDecoder(root: self.require(key)).container(keyedBy: NestedKey.self)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
      try _ContainerDecoder(root: self.require(key)).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
      _ContainerDecoder(root: object)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
      _ContainerDecoder(root: try self.require(key))
    }
  }
}

extension JSDecoder {
  private struct UnkeyedContainer: UnkeyedDecodingContainer {
    let array: JSValue
    var codingPath: [CodingKey]
    var currentIndex: Int = 0

    var count: Int? {
      Int(array.objectForKeyedSubscript("length").toInt32())
    }

    var isAtEnd: Bool {
      self.currentIndex >= (self.count ?? 0)
    }

    mutating func requireNext() throws -> JSValue {
      guard !self.isAtEnd else { throw JSDecodingError.outOfBounds }
      defer { self.currentIndex += 1 }
      return self.array.objectAtIndexedSubscript(self.currentIndex)
    }

    mutating func decodeNil() throws -> Bool {
      let value = try self.requireNext()
      return value.isNull || value.isUndefined
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
      try Bool(jsValue: self.requireNext())
    }

    mutating func decode(_ type: String.Type) throws -> String {
      try String(jsValue: self.requireNext())
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
      try Double(jsValue: self.requireNext())
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
      try Int(jsValue: self.requireNext())
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
      try Int8(jsValue: self.requireNext())
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
      try Int16(jsValue: self.requireNext())
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
      try Int32(jsValue: self.requireNext())
    }

    mutating func decode(_ type: Int64.Type) throws -> Int64 {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        try Int64(jsValue: self.requireNext())
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
      try UInt(jsValue: self.requireNext())
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
      try UInt8(jsValue: self.requireNext())
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
      try UInt16(jsValue: self.requireNext())
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
      try UInt32(jsValue: self.requireNext())
    }

    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        try UInt64(jsValue: self.requireNext())
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
      let jsValue = try self.requireNext()
      if let converted = try T(convertingIfAble: jsValue) {
        return converted
      }
      return try JSDecoder().decode(T.self, from: jsValue)
    }

    mutating func nestedContainer<NestedKey>(
      keyedBy: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
      try _ContainerDecoder(root: self.requireNext()).container(keyedBy: NestedKey.self)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
      try _ContainerDecoder(root: self.requireNext()).unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
      try _ContainerDecoder(root: self.requireNext())
    }
  }
}

extension JSDecoder {
  private struct SingleContainer: SingleValueDecodingContainer {
    let value: JSValue
    var codingPath: [CodingKey]

    func decodeNil() -> Bool {
      self.value.isNull || self.value.isUndefined
    }

    func decode(_ type: Bool.Type) throws -> Bool {
      try Bool(jsValue: self.value)
    }

    func decode(_ type: String.Type) throws -> String {
      try String(jsValue: self.value)
    }

    func decode(_ type: Double.Type) throws -> Double {
      try Double(jsValue: self.value)
    }

    func decode(_ type: Int.Type) throws -> Int {
      try Int(jsValue: self.value)
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
      try Int8(jsValue: self.value)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
      try Int16(jsValue: self.value)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
      try Int32(jsValue: self.value)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        try Int64(jsValue: self.value)
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    func decode(_ type: UInt.Type) throws -> UInt {
      try UInt(jsValue: self.value)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
      try UInt8(jsValue: self.value)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
      try UInt16(jsValue: self.value)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
      try UInt32(jsValue: self.value)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
      if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
        try UInt64(jsValue: self.value)
      } else {
        throw JSBigIntNotSupportedError()
      }
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
      if let converted = try T(convertingIfAble: self.value) {
        return converted
      }
      return try JSDecoder().decode(T.self, from: self.value)
    }
  }
}

// MARK: - JSDecodingError

private enum JSDecodingError: Error {
  case typeMismatch
  case missingKey
  case outOfBounds
}

// MARK: - Helpers

extension Decodable {
  fileprivate init?(convertingIfAble jsValue: JSValue) throws {
    guard let initializer = Self.self as? any ConvertibleFromJSValue.Type else {
      return nil
    }
    func open<T: ConvertibleFromJSValue>(_ t: T.Type) throws -> T {
      try t.init(jsValue: jsValue)
    }
    self = try open(initializer) as! Self
  }
}
