// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "mcenergy",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "MCEnergyCore",
            linkerSettings: [.linkedLibrary("IOReport")]
        ),
        .executableTarget(
            name: "mcenergy",
            dependencies: ["MCEnergyCore"]
        ),
        .testTarget(
            name: "MCEnergyCoreTests",
            dependencies: ["MCEnergyCore"]
        ),
    ]
)
