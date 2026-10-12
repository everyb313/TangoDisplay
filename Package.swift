// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TangoDisplay",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
        // TagLib (MPL-1.1) packaged for SwiftPM — the only tag *writer*; reads stay on AVFoundation
        .package(url: "https://github.com/sbooth/CXXTagLib", from: "2.3.2")
    ],
    targets: [
        // Pure-logic library — no AppKit/SwiftUI — importable by both the app and the test runner
        .target(
            name: "TangoDisplayCore",
            path: "Sources/TangoDisplayCore"
        ),
        // ObjC/ObjC++ helpers — @try/@catch wrappers Swift cannot express, plus the
        // ShellacFilters declick/dehum DSP cores wrapped as in-process Audio Units,
        // and the TagLib tag writer behind Setlist's Edit Tags
        .target(
            name: "TangoDisplayObjC",
            dependencies: [.product(name: "taglib", package: "CXXTagLib")],
            path: "Sources/TangoDisplayObjC",
            exclude: ["shellac/README.md", "shellac/LICENSE.txt"],
            publicHeadersPath: "include"
        ),
        // Main app executable
        .executableTarget(
            name: "TangoDisplay",
            dependencies: [
                "TangoDisplayCore",
                "TangoDisplayObjC",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/TangoDisplay",
            resources: [
                .copy("Resources/SetlistLogo.png"),
                .copy("Resources/RemoteUI")
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        // Lightweight test runner executable — no XCTest needed (CLI tools only, no Xcode.app)
        // Usage: swift run TangoDisplayTests
        .executableTarget(
            name: "TangoDisplayTests",
            dependencies: ["TangoDisplayCore", "TangoDisplayObjC"],
            path: "Tests/TangoDisplayTests"
        )
    ]
)
