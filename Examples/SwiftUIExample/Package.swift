// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftUIExample",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .executable(name: "SwiftUIExample", targets: ["SwiftUIExample"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "SwiftUIExample",
            dependencies: [
                .product(name: "XMoneyPaymentSheet", package: "XMoneyPaymentSheet"),
            ],
            path: "Sources"
        ),
    ]
)
