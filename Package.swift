// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XMoneyPaymentSheet",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "XMoneyCore", targets: ["XMoneyCore"]),
        .library(name: "XMoneyApplePay", targets: ["XMoneyApplePay"]),
        .library(name: "XMoneyPaymentElement", targets: ["XMoneyPaymentElement"]),
        .library(name: "XMoneyPaymentSheet", targets: ["XMoneyPaymentSheet"]),
    ],
    targets: [
        .target(
            name: "XMoneyCore",
            dependencies: [],
            path: "Sources/XMoneyCore",
            resources: [
                .process("../../Resources"),
                .process("Resources"),
                .copy("../../PrivacyInfo.xcprivacy"),
            ],
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("WebKit"),
            ]
        ),
        .target(
            name: "XMoneyApplePayObjC",
            path: "Sources/XMoneyApplePayObjC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "XMoneyApplePay",
            dependencies: ["XMoneyCore", "XMoneyApplePayObjC"],
            path: "Sources/XMoneyApplePay",
            linkerSettings: [
                .linkedFramework("PassKit"),
                .linkedFramework("WebKit"),
            ]
        ),
        .target(
            name: "XMoneyPaymentElement",
            dependencies: ["XMoneyCore"],
            path: "Sources/XMoneyPaymentElement",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("PassKit"),
                .linkedFramework("WebKit"),
            ]
        ),
        .target(
            name: "XMoneyPaymentSheet",
            dependencies: ["XMoneyCore", "XMoneyPaymentElement", "XMoneyApplePay"],
            path: "Sources/XMoneyPaymentSheet",
            linkerSettings: [
                .linkedFramework("PassKit"),
                .linkedFramework("WebKit"),
            ]
        ),
        .testTarget(
            name: "XMoneyPaymentSheetTests",
            dependencies: ["XMoneyPaymentSheet", "XMoneyCore", "XMoneyPaymentElement"],
            path: "Tests/XMoneyPaymentSheetTests",
            resources: [
                .copy("test-vectors.json"),
            ]
        ),
        .testTarget(
            name: "XMoneyCoreTests",
            dependencies: ["XMoneyCore"],
            path: "Tests/XMoneyCoreTests",
            resources: [
                .copy("test-vectors.json"),
            ]
        ),
        .testTarget(
            name: "XMoneyPaymentElementTests",
            dependencies: ["XMoneyPaymentElement", "XMoneyCore"],
            path: "Tests/XMoneyPaymentElementTests"
        ),
    ]
)
