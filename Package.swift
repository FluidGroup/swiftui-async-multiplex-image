// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AsyncMultiplexImage",
  platforms: [
    .iOS(.v16),
  ],
  products: [
    .library(
      name: "AsyncMultiplexImage",
      targets: ["AsyncMultiplexImage"]
    ),  
    .library(
      name: "AsyncMultiplexImage-Nuke",
      targets: ["AsyncMultiplexImage-Nuke"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
    .package(url: "https://github.com/FluidGroup/swiftui-support.git", from: "0.12.0")
  ],
  targets: [
    .target(
      name: "AsyncMultiplexImage",
      dependencies: [.product(name: "SwiftUISupportBackport", package: "swiftui-support")]
    ),
    .target(
      name: "AsyncMultiplexImage-Nuke",
      dependencies: ["Nuke", "AsyncMultiplexImage"]
    ),
    .testTarget(
      name: "AsyncMultiplexImageTests",
      dependencies: ["AsyncMultiplexImage"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
