import CustomDump
import JavaScriptCoreExtras
import Testing

@Suite("JSCrypto tests")
struct JSCryptoTests {
  private let context = JSContext()!

  init() throws {
    try self.context.install([.consoleLogging, .crypto])
  }

  @Test("Random UUID Generates Different UUIDs")
  func differentUUIDs() {
    let value = self.context.evaluateScript(
      """
      const results = new Set()
      for (let i = 0; i < 1000; i++) {
        results.add(crypto.randomUUID())
      }
      results
      """
    )
    expectNoDifference(value?.objectForKeyedSubscript("size").toInt32(), 1000)
  }

  @Test("Random UUID Generates UUID v4")
  func uuidv4() throws {
    let value = self.context.evaluateScript(
      """
      crypto.randomUUID()
      """
    )
    let uuid = try #require(value.flatMap { UUID(uuidString: $0.toString()) })
    expectNoDifference(uuid.version, 4)
  }

  @Test("Random UUID Uses Lower Case")
  func uuidLowerCase() throws {
    let value = self.context.evaluateScript(
      """
      const uuid = crypto.randomUUID()
      const isLowercase = uuid === uuid.toLowerCase()
      isLowercase
      """
    )
    expectNoDifference(value?.toBool(), true)
  }

  @Test("crypto is Instace of Crypto")
  func cryptoInstance() {
    let value = self.context.evaluateScript(
      """
      crypto instanceof Crypto
      """
    )
    expectNoDifference(value?.toBool(), true)
  }

  @Test("Get Random Values, Expects Array Buffer View")
  func randomValuesExpectsArrayBufferView() {
    expectErrorMessage(
      js: "crypto.getRandomValues([])",
      message:
        "Failed to execute 'getRandomValues' on 'Crypto': parameter 1 is not of type 'ArrayBufferView'.",
      in: self.context
    )
  }

  @Test("Get Random Values, Returns Instance View")
  func returnsSameRandomValuesInstance() {
    let value = self.context.evaluateScript(
      """
      const array = new Uint8Array(32)
      const array2 = crypto.getRandomValues(array)
      array === array2
      """
    )
    expectNoDifference(value?.toBool(), true)
  }

  @Test("Get Random Values, Fills Uint8Arrays Randomly")
  func fillsUint8ArrayWithRandomValues() throws {
    let value = self.context.evaluateScript(
      """
      const isEqual = (arr1, arr2) => {
        for (let i = 0; i < arr1.length; i++) {
          if (arr1[i] !== arr2[i]) return false
        }
        return true
      }
      const results = []
      for (let i = 0; i < 3; i++) {
        results.push(crypto.getRandomValues(new Uint8Array(32)))
      }
      const result = !isEqual(results[0], results[1])
        && !isEqual(results[1], results[2])
        && !isEqual(results[0], results[2])
      result
      """
    )
    expectNoDifference(value?.toBool(), true)
  }

  @Test("Get Random Values Fills Uint16Array to Byte Length")
  func fillsToByteLength() throws {
    let value = self.context.evaluateScript(
      """
      crypto.getRandomValues(new Uint16Array(32))
      """
    )
    let array = try #require(value?.toArray().compactMap { $0 as? UInt16 })
    #expect(Array(array[16...]) != Array(repeating: 0, count: 16))
  }
}

extension UUID {
  fileprivate var version: Int {
    Int(self.uuid.6 >> 4)
  }
}
