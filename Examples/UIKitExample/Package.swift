// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UIKitExample",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .executable(name: "UIKitExample", targets: ["UIKitExample"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "UIKitExample",
            dependencies: [
                .product(name: "XMoneyPaymentSheet", package: "XMoneyPaymentSheet"),
            ],
            path: "Sources"
        ),
    ]
)
