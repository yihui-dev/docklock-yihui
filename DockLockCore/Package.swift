// swift-tools-version:5.9
import PackageDescription

// Platform-independent logic shared by the DockLock app, its CLI and its tests.
// The Xcode project compiles these sources straight into the app target; this
// package exists so the logic can be unit-tested with `swift test` (macOS or Linux).
let package = Package(
    name: "DockLockCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DockLockCore", targets: ["DockLockCore"]),
    ],
    targets: [
        .target(name: "DockLockCore"),
        .testTarget(name: "DockLockCoreTests", dependencies: ["DockLockCore"]),
    ]
)
