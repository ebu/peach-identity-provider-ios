// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PeachIdentityProvider",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PeachIdentityProvider",
            targets: ["PeachIdentityProvider"]),
    ],
    dependencies: [
                
        .package(url: "https://github.com/SRGSSR/FXReachability", revision: "1eac916df0045630e779fa60eef22ed0d185e15f"),
        
        .package(url: "https://github.com/SRGSSR/libextobjc.git", revision: "30ee5b73bdf57a826978aa146881277f22369be1"),
        
        .package(url: "https://github.com/SRGSSR/MAKVONotificationCenter.git", revision: "60395e0601ffd4a784856b423d4cac558366276d"),
        
        .package(url: "https://github.com/kishikawakatsumi/UICKeyChainStore.git", revision: "db869212bc69b6198a62efe03e2f5fc8e19c6b65")
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "PeachIdentityProvider"
        )
    ]
)
