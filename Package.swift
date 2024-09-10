// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AsyncMultiplexImage",
  platforms: [
    .iOS(.v15),
  ],
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other packages.
    .library(
      name: "AsyncMultiplexImage",
      targets: ["AsyncMultiplexImage"]
    ),
    
    .library(
      name: "AsyncMultiplexImage-Nuke",
      targets: ["AsyncMultiplexImage-Nuke"]
    ),
    
    .library(
      name: "AsyncMultiplexImageDemo",
      targets: ["AsyncMultiplexImageDemo"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
    .package(url: "https://github.com/FluidGroup/swiftui-support.git", from: "0.10.0")
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
    .target(
      name: "AsyncMultiplexImageDemo",
      dependencies: ["AsyncMultiplexImage", "AsyncMultiplexImage-Nuke", "Nuke"]
    ),
    .testTarget(
      name: "AsyncMultiplexImageTests",
      dependencies: ["AsyncMultiplexImage"]
    ),
  ]
)
