// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPXViewer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "GPXViewer",
            targets: ["GPXViewer"]
        )
    ],
    targets: [
        .executableTarget(
            name: "GPXViewer",
            path: "GPXViewer",
            exclude: ["Info.plist", "GPXViewer.entitlements"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
