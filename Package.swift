// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "javascript-core-extras",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
    .visionOS(.v1)
  ],
  products: [
    .library(name: "JavaScriptCoreExtras", targets: ["JavaScriptCoreExtras"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.4")),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.6"),
    .package(
      url: "https://github.com/pointfreeco/xctest-dynamic-overlay",
      .upToNextMajor(from: "1.2.2")
    )
  ],
  targets: [
    .target(
      name: "JavaScriptCoreExtras",
      dependencies: [
        "_CJavaScriptCoreExtras",
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
      ],
      resources: [.process("js")]
    ),
    .testTarget(
      name: "JavaScriptCoreExtrasTests",
      dependencies: [
        "JavaScriptCoreExtras",
        .product(name: "Clocks", package: "swift-clocks"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
      ]
    ),
    .target(name: "_CJavaScriptCoreExtras")
  ]
)
