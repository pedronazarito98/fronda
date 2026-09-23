// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Harness",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Harness", targets: ["HarnessUI"]),
        .executable(name: "HarnessCLI", targets: ["HarnessCLI"]),
        .executable(name: "HarnessService", targets: ["HarnessService"]),
        .library(name: "HarnessIPC", targets: ["HarnessIPC"]),
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(
            name: "CTreeSitter", path: "Vendor/CTreeSitter", sources: ["wrappers"], publicHeadersPath: "include",
            cSettings: [.headerSearchPath("runtime"), .headerSearchPath("grammars/typescript/src")]),
        .target(name: "HarnessDomain"),
        .target(name: "HarnessInfrastructure", dependencies: ["HarnessDomain", "CSQLite", "CTreeSitter"]),
        .target(name: "HarnessProviders", dependencies: ["HarnessDomain", "HarnessInfrastructure"]),
        .target(name: "HarnessCore", dependencies: ["HarnessDomain", "HarnessInfrastructure", "HarnessProviders"]),
        .target(name: "HarnessIPC", dependencies: ["HarnessDomain", "HarnessInfrastructure"]),
        .executableTarget(name: "HarnessService", dependencies: ["HarnessCore", "HarnessIPC"]),
        .executableTarget(name: "HarnessCLI", dependencies: ["HarnessIPC"]),
        .executableTarget(name: "HarnessUI", dependencies: ["HarnessIPC"]),
        .testTarget(name: "HarnessTests", dependencies: ["HarnessCore", "HarnessDomain", "HarnessInfrastructure"]),
    ]
)
