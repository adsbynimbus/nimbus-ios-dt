//
//  DTNativeAdViewType.swift
//  NimbusDTKit
//  Created on 5/29/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import UIKit

/**
 A `UIView` subclass capable of presenting Moloco native ads.
 
 Pass an instance conforming to this protocol to `DigitalTurbineExtension.nativeAdViewProvider`
 to render a native Digital Turbine ad.
 */
public protocol DTNativeAdViewType: UIView {
    
    /// Media View displaying IANativeAdAssets.mediaView
    var mediaView: UIView? { get }
    
    /// Icon View displaying IANativeAdAssets.appIcon
    var iconView: UIView? { get }
    
    /**
     Array of clickable views.
     
     It's recommended to implement this as a computed property, making
     it very easy to return the views you consider clickable, for instance:
     ```swift
     class MyNativeView: UIView, DTNativeAdViewType {
        let mediaView: UIView
        let installButton: UIButton
        
        var clickableViews: [mediaView, installButton]
     }
     ```
     */
    var clickableViews: [UIView] { get }
}
