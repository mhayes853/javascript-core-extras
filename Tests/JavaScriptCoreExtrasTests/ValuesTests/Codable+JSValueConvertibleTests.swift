import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("Codable+JSValueConvertible tests")
struct CodableJSValueConvertibleTests {
  @Test("Single")
  func single() throws {
    let context = JSContext()!
    let single = Single(a: 10)
    let jsValue = try single.jsValue(in: context)

    expectNoDifference(jsValue.isNumber, true)
    expectNoDifference(jsValue.toInt32(), 10)

    expectNoDifference(try Single(jsValue: jsValue), single)
  }

  @Test("Unkeyed")
  func unkeyed() throws {
    let context = JSContext()!
    let unkeyed = Unkeyed(a: [10, 20])
    let jsValue = try unkeyed.jsValue(in: context)

    expectNoDifference(jsValue.isArray, true)
    expectNoDifference(jsValue.objectAtIndexedSubscript(0).toInt32(), 10)
    expectNoDifference(jsValue.objectAtIndexedSubscript(1).toInt32(), 20)

    expectNoDifference(try Unkeyed(jsValue: jsValue), unkeyed)
  }

  @Test("Multifield")
  func multifield() throws {
    let context = JSContext()!
    let multifield = MultiField(a: "hello", b: 10)
    let jsValue = try multifield.jsValue(in: context)

    expectNoDifference(jsValue.isObject, true)
    expectNoDifference(jsValue.objectForKeyedSubscript("a").toString(), "hello")
    expectNoDifference(jsValue.objectForKeyedSubscript("b").toInt32(), 10)

    expectNoDifference(try MultiField(jsValue: jsValue), multifield)
  }

  @Test("Nested")
  func nested() throws {
    let context = JSContext()!
    let nested = Nested(a: MultiField(a: "hello", b: 10), b: 20)
    let jsValue = try nested.jsValue(in: context)

    expectNoDifference(jsValue.isObject, true)
    expectNoDifference(jsValue.objectForKeyedSubscript("a").isObject, true)
    expectNoDifference(
      jsValue.objectForKeyedSubscript("a").objectForKeyedSubscript("a").toString(),
      "hello"
    )
    expectNoDifference(
      jsValue.objectForKeyedSubscript("a").objectForKeyedSubscript("b").toInt32(),
      10
    )
    expectNoDifference(jsValue.objectForKeyedSubscript("b").toInt32(), 20)

    expectNoDifference(try Nested(jsValue: jsValue), nested)
  }

  @Test("Decoding Failures From Empty Object")
  func decodingFailuresFromEmptyObject() throws {
    let context = JSContext()!
    let jsValue = JSValue(newObjectIn: context)!

    #expect(throws: Error.self) {
      try MultiField(jsValue: jsValue)
    }
    #expect(throws: Error.self) {
      try Nested(jsValue: jsValue)
    }
    #expect(throws: Error.self) {
      try Single(jsValue: jsValue)
    }
    #expect(throws: Error.self) {
      try Unkeyed(jsValue: jsValue)
    }
  }

  @Test("Encodes And Decodes Object With Date")
  func encodesAndDecodesObjectWithDate() throws {
    struct WithDate: Hashable, Codable, JSValueConvertible {
      var date: Date
    }

    let context = JSContext()!
    let withDate = WithDate(date: .distantPast)
    let jsValue = try withDate.jsValue(in: context)

    expectNoDifference(jsValue.objectForKeyedSubscript("date").isDate, true)
    expectNoDifference(jsValue.objectForKeyedSubscript("date").toDate(), .distantPast)

    expectNoDifference(try WithDate(jsValue: jsValue), withDate)
  }

  @Test("Encodes And Decodes Object With UUID")
  func encodesAndDecodesObjectWithUUID() throws {
    struct WithUUID: Hashable, Codable, JSValueConvertible {
      var uuid: UUID
    }

    let context = JSContext()!
    let withUUID = WithUUID(uuid: UUID())
    let jsValue = try withUUID.jsValue(in: context)

    expectNoDifference(jsValue.objectForKeyedSubscript("uuid").isString, true)
    expectNoDifference(jsValue.objectForKeyedSubscript("uuid").toString(), withUUID.uuid.uuidString)

    expectNoDifference(try WithUUID(jsValue: jsValue), withUUID)
  }

  @Test("Encodes And Decodes Object With JSValueConvertible")
  func encodesAndDecodesObjectWithJSValueConvertible() throws {
    struct Convertible: Hashable, Codable, JSValueConvertible {
      func jsValue(in context: JSContext) -> JSValue {
        JSValue(int32: 1, in: context)
      }

      init() {}

      init(jsValue: JSValue) throws {
        guard jsValue.isNumber, jsValue.toInt32() == 1 else { throw SomeError() }
      }

      private struct SomeError: Error {}
    }

    struct WithConvertible: Hashable, Codable, JSValueConvertible {
      var convertible: Convertible
    }

    let context = JSContext()!
    let withConvertible = WithConvertible(convertible: Convertible())
    let jsValue = try withConvertible.jsValue(in: context)

    expectNoDifference(jsValue.objectForKeyedSubscript("convertible").toInt32(), 1)

    expectNoDifference(try WithConvertible(jsValue: jsValue), withConvertible)
  }

  @Test("With Optional")
  func withOptional() throws {
    struct WithOptional: Hashable, Codable, JSValueConvertible {
      var value: Int?
    }

    let context = JSContext()!
    try context.install([.consoleLogging])
    let withOptional = WithOptional(value: nil)
    let jsValue = try withOptional.jsValue(in: context)

    expectNoDifference(jsValue.hasProperty("value"), false)

    expectNoDifference(try WithOptional(jsValue: jsValue), withOptional)
  }

  @Test("Fails Encoding")
  func failsEncoding() throws {
    struct SomeError: Error {}
    struct Failing: Hashable, Codable, ConvertibleToJSValue {
      func encode(to encoder: any Encoder) throws {
        throw SomeError()
      }
    }

    let context = JSContext()!
    let failing = Failing()
    #expect(throws: SomeError.self) { try failing.jsValue(in: context) }
  }

  @Test("Empty")
  func empty() throws {
    struct Empty: Hashable, Codable, JSValueConvertible {}

    let context = JSContext()!
    let empty = Empty()
    let jsValue = try empty.jsValue(in: context)

    expectNoDifference(jsValue.isObject, true)
    expectNoDifference(
      context.objectForKeyedSubscript("Object")?
        .invokeMethod("getOwnPropertyNames", withArguments: [jsValue])?
        .objectForKeyedSubscript("length")
        .toInt32(),
      0
    )

    expectNoDifference(try Empty(jsValue: jsValue), empty)
  }

  @Test("Super Encoding With Key")
  func superEncodingWithKey() throws {
    struct Value: Hashable, Codable, ConvertibleToJSValue {
      let inner: MultiField

      func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try self.inner.encode(to: container.superEncoder(forKey: .inner))
      }
    }

    let context = JSContext()!
    let value = Value(inner: MultiField(a: "a", b: 42))
    let jsValue = try value.jsValue(in: context)

    expectNoDifference(jsValue.objectForKeyedSubscript("inner").isObject, true)
  }

  @Test("Super Encoding Without Key")
  func superEncodingWithoutKey() throws {
    struct Value: Hashable, Codable, ConvertibleToJSValue {
      let inner: MultiField

      func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try self.inner.encode(to: container.superEncoder())
      }
    }

    let context = JSContext()!
    let value = Value(inner: MultiField(a: "a", b: 42))
    let jsValue = try value.jsValue(in: context)

    expectNoDifference(jsValue.objectForKeyedSubscript("super").isObject, true)
  }

  @Test("Super Encoding Unkeyed")
  func superEncodingUnkeyed() throws {
    struct Value: Hashable, Codable, ConvertibleToJSValue {
      let inner: MultiField

      func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try self.inner.encode(to: container.superEncoder())
      }
    }

    let context = JSContext()!
    let value = Value(inner: MultiField(a: "a", b: 42))
    let jsValue = try value.jsValue(in: context)

    expectNoDifference(jsValue.objectAtIndexedSubscript(0).isObject, true)
  }

  @Test("Nil Value Encodes As Undefined")
  func nilValueEncodesAsUndefined() throws {
    struct Value: Hashable, Codable, ConvertibleToJSValue {
      let inner: MultiField?

      func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNil(forKey: .inner)
      }
    }

    let context = JSContext()!
    let value = Value(inner: nil)
    let jsValue = try value.jsValue(in: context)

    expectNoDifference(jsValue.hasProperty("inner"), true)
    expectNoDifference(jsValue.objectForKeyedSubscript("inner").isUndefined, true)
  }
}

private struct MultiField: Hashable, Codable, JSValueConvertible {
  var a: String
  var b: Int
}

private struct Nested: Hashable, Codable, JSValueConvertible {
  var a: MultiField
  var b: Int
}

private struct Single: Hashable, Codable, JSValueConvertible {
  var a: Int

  init(a: Int) {
    self.a = a
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.a)
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.a = try container.decode(Int.self)
  }
}

private struct Unkeyed: Hashable, Codable, JSValueConvertible {
  var a: [Int]

  init(a: [Int]) {
    self.a = a
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    for element in self.a {
      try container.encode(element)
    }
  }

  init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()

    self.a = []
    while !container.isAtEnd {
      self.a.append(try container.decode(Int.self))
    }
  }
}
