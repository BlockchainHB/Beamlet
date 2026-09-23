// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BeamletCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BeamletCore", targets: ["BeamletCore"]),
        .executable(name: "Beamlet", targets: ["Beamlet"]),
        .executable(name: "BeamletRunner", targets: ["BeamletRunner"])
    ],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")],
    targets: [
        .target(name: "BeamletCore", path: "Sources/Core"),
        .executableTarget(name: "Beamlet", dependencies: ["BeamletCore", .product(name: "Sparkle", package: "Sparkle")], path: "Sources/App",
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .executableTarget(name: "BeamletRunner", path: "Sources/Runner"),
        .testTarget(name: "BeamletCoreTests", dependencies: ["BeamletCore"], path: "Tests/Core"),
        .testTarget(name: "BeamletAppTests", dependencies: ["Beamlet", "BeamletRunner"], path: "Tests/App")
    ]
)
