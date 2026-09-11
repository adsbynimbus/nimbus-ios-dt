// swift-tools-version: 6.1

import PackageDescription

var package = Package(
    name: "NimbusDTKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
           name: "NimbusDTKit",
           targets: ["NimbusDTKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/inner-active/DTExchangeSDK-iOS-SPM", from: "8.4.7")
    ],
    targets: [
        .target(
            name: "NimbusDTKit",
            dependencies: [
                .product(name: "NimbusKit", package: "nimbus-ios-sdk"),
                .product(name: "DTExchangeSDK", package: "DTExchangeSDK-iOS-SPM")
            ]
        ),
        .testTarget(
            name: "NimbusDTKitTests",
            dependencies: ["NimbusDTKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [.unsafeFlags(["-ObjC"])]
        ),
    ]
)

package.dependencies.append(.package(url: "https://github.com/adsbynimbus/nimbus-ios-sdk", from: "3.0.0-rc.4"))
