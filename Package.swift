// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCalendar",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MacCalendar", targets: ["MacCalendar"]),
        // Library product so Xcode makes a scheme for it: SwiftUI previews do not run in executable targets.
        .library(name: "MacCalendarUI", targets: ["MacCalendarUI"]),
    ],
    targets: [
        .target(name: "MacCalendarCore"),
        .target(name: "MacCalendarUI", dependencies: ["MacCalendarCore"]),
        .executableTarget(name: "MacCalendar", dependencies: ["MacCalendarUI"]),
        .testTarget(name: "MacCalendarCoreTests", dependencies: ["MacCalendarCore"]),
    ]
)
