//
//  DigitalTurbineExtension.swift
//  Nimbus
//  Created on 5/27/26
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import IASDKCore

/// Nimbus extension for Digital Turbine.
///
/// Enables Digital Turbine rendering when included in `Nimbus.initialize(...)`.
/// Supports dynamic enable/disable at runtime.
///
/// ### Notes:
///   - Instantiate within the `Nimbus.initialize` block; the extension is installed and enabled automatically.
///   - Disable rendering with `DigitalTurbineExtension.disable()`.
///   - Re-enable rendering with `DigitalTurbineExtension.enable()`.
public struct DigitalTurbineExtension: NimbusRequestExtension, NimbusRenderExtension {
    @_documentation(visibility: internal)
    public var interceptor: any NimbusRequest.Interceptor
    
    @_documentation(visibility: internal)
    public var enabled = true
    
    @_documentation(visibility: internal)
    public var network: String { "digitalturbinesdk" }
    
    @_documentation(visibility: internal)
    public var controllerType: AdController.Type { DTAdController.self }
    
    /// Creates a Digital Turbine extension.
    ///
    /// - Parameter appId: Digital Turbine App ID. If provided, Nimbus initializes the Digital Turbine SDK automatically.
    ///
    /// ##### Usage
    /// ```swift
    /// Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    ///     DigitalTurbineExtension(appId: true) // Enables Digital Turbine rendering
    /// }
    /// ```
    public init(appId: String? = nil) {
        self.interceptor = DTRequestInterceptor()
        
        guard let appId else {
            Nimbus.Log.lifecycle.debug("Skipping Digital Turbine SDK initialization, appId was not provided")
            return
        }
        
        IASDKCore.sharedInstance().initWithAppID(appId, completionBlock: { success, error in
            if let error {
                Nimbus.Log.lifecycle.debug("Digital Turbine SDK initialization failed, error: \(error.localizedDescription)")
            } else {
                Nimbus.Log.lifecycle.debug("Digital Turbine SDK initialization completed")
            }
        }, completionQueue: nil)
        
        IASDKCore.sharedInstance().muteAudio = true
        IASDKCore.sharedInstance().mediationType = IAMediationNimbus()
    }
    
    @_documentation(visibility: internal)
    public func coppaDidChange(coppa: Bool) {
        IASDKCore.sharedInstance().coppaApplies = coppa ? .true : .false
    }
}

final class IAMediationNimbus: IAMediation {
    override func name() -> String { "nimbus" }
    override func version() -> String { Nimbus.version }
}

public extension DigitalTurbineExtension {
    /**
     The UIView returned from this method should have all of the data set from the native ad
     on children views such as the call to action, image data, title, privacy icon etc.
     The view returned from this method should not be attached to the container passed in as
     it will be attached at a later time during the rendering process.
     
     NOTE: DO NOT set nativeAd.delegate. Nimbus uses this delegate and forwards events as NimbusEvent. You may
     listen set AdController.delegate and listen to didReceiveNimbusEvent() and didReceiveNimbusError() instead.
     
     Please set the GADNativeAdView.nativeAd property at the appropriate time, as the correct timing may vary depending on the AdChoices settings.
     
     - Parameters:
       - container: The container the layout will be attached to
       - nativeAd: The Digital Turbine native ad assets
     
     - Returns: Your custom UIView. DO NOT attach the view to the hierarchy yourself.
     */
    @MainActor
    @preconcurrency
    static var nativeAdViewProvider: ((_ container: UIView, _ nativeAd: IANativeAdAssets) -> DTNativeAdViewType)?
}
