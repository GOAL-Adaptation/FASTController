// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "FASTController",
  products: [
    .library(name: "FASTController", targets: ["FASTController"]),
  ],
  targets: [
    .target(name: "FASTController"),
    .testTarget(name: "FASTControllerTests", dependencies: ["FASTController"])
  ],
  swiftLanguageVersions: [4]
)
