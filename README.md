# NimbusDTKit

A Nimbus SDK extension for **Digital Turbine bidding and rendering**. It enriches Nimbus ad requests with Digital Turbine demand and handles ad rendering through the Digital Turbine SDK when it wins the auction.

## Versioning
 
NimbusDTKit **major versions are kept in sync** with the Digital Turbine SDK. For example, NimbusDTKit `8.x.x` depends on Digital Turbine SDK `8.x.x`.
 
Minor and patch versions are independent — a NimbusDTKit patch release does not necessarily correspond to a Digital Turbine SDK patch release, and vice versa.
 
| NimbusDTKit | Digital Turbine SDK |
|---|---|
| 8.x.x | 8.x.x |

## Installation

### Swift Package Manager

#### Xcode Project

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the repository URL:
   ```
   https://github.com/adsbynimbus/nimbus-ios-dt
   ```
3. Set the dependency rule to **Up to Next Major Version** and enter `8.0.0` as the minimum.
4. Click **Add Package** and select the **NimbusDTKit** library when prompted.

#### Package.swift

If you're managing dependencies through a `Package.swift` file, add the following:

```swift
dependencies: [
    .package(url: "https://github.com/adsbynimbus/nimbus-ios-dt", from: "8.0.0")
]
```

Then add the product to your target:

```swift
.product(name: "NimbusDTKit", package: "nimbus-ios-dt")
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'NimbusDTKit'
```

Then run:

```sh
pod install
```

## Usage
 
Navigate to where you call `Nimbus.initialize` and register the `DigitalTurbineExtension`:
 
```swift
import NimbusDTKit
 
Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    DigitalTurbineExtension(accountId: "<accountId>")
}
```

If you provide an account ID, Nimbus will automatically initialize the Digital Turbine SDK.

That's it — Digital Turbine is now enabled in all upcoming requests.

## Documentation

- [Nimbus iOS SDK Documentation](https://docs.adsbynimbus.com/docs/sdk/ios) — integration guides, configuration, and API reference.
- [DocC API Reference](https://iosdocs.adsbynimbus.com) — auto-generated documentation for the latest release.

## Sample App

See NimbusDTKit in action in our public [sample app repository](https://github.com/adsbynimbus/nimbus-ios-sample), which demonstrates end-to-end integration including setup, bid requests, and ad rendering.
