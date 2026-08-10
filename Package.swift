// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sanne",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure app logic + UI. Testable via `@testable import SanneKit`.
        // The executable target is a one-line trampoline so SPM can still emit a `Sanne` binary.
        .target(
            name: "SanneKit",
            path: "Sources/Sanne",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Sanne",
            dependencies: ["SanneKit"],
            path: "Sources/SanneApp"
        ),
        .testTarget(
            name: "SanneTests",
            dependencies: ["SanneKit"],
            path: "Tests/SanneTests"
        )
    ]
)
