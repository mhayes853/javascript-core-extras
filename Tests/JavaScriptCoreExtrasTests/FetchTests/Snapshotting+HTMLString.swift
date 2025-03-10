import SnapshotTesting

extension Snapshotting where Value == String, Format == String {
  /// A snapshot strategy for comparing HTML files.
  static var htmlString: Self {
    var snapshotting = SimplySnapshotting.lines.pullback { (pattern: String) in
      pattern
    }
    snapshotting.pathExtension = "html"
    return snapshotting
  }
}
