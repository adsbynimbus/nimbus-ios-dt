//
//  DTAdController.swift
//  NimbusDTKit
//  Created on 5/27/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import UIKit
import NimbusKit
import IASDKCore

// Internal: Do NOT implement delegate conformance as separate extensions as the methods will not be found in runtime when built as a static library
final class DTAdController: AdController,
                            @MainActor IAUnitDelegate,
                            @MainActor IANativeAdDelegate,
                            @MainActor IAMRAIDContentDelegate,
                            @MainActor IAVideoContentDelegate {
    
    // MARK: - Properties
    
    // MARK: DT properties
    var mraidContentController: IAMRAIDContentController?
    var videoContentController: IAVideoContentController?
    var fullscreenController: IAFullscreenUnitController?
    var inlineController: IAViewUnitController?
    var spot: IAAdSpot?
    var nativeSpot: IANativeAdSpot?
    var nativeAssets: IANativeAdAssets?
    
    override class func setup(
        response: NimbusResponse,
        container: UIView,
        adPresentingViewController: UIViewController?
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    override class func setupBlocking(
        response: NimbusResponse,
        isRewarded: Bool,
        adPresentingViewController: UIViewController
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: true,
            isRewarded: isRewarded,
            container: nil,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    override func load() {
        switch adRenderType {
        case .banner:
            loadBannerAd()
        case .native:
            loadNativeAd()
        case .interstitial, .rewarded:
            loadFullscreenAd()
        @unknown default:
            sendNimbusError(.dt(reason: .unsupported, stage: .render, detail: "adRenderType: \(adRenderType.rawValue)"))
        }
    }
    
    func loadBannerAd() {
        mraidContentController = IAMRAIDContentController.build { [weak self] builder in
            builder.mraidContentDelegate = self
        }
        guard let mraidContentController else {
            sendNimbusError(.dt(stage: .render, detail: "Could not build IAMRAIDContentController"))
            return
        }
        
        inlineController = IAViewUnitController.build { [weak self] builder in
            builder.unitDelegate = self
            builder.addSupportedContentController(mraidContentController)
        }
        guard let inlineController else {
            sendNimbusError(.dt(stage: .render, detail: "Could not build IAViewUnitController"))
            return
        }
        
        spot = IAAdSpot.build { builder in
            builder.addSupportedUnitController(inlineController)
        }
        guard let spot else {
            sendNimbusError(.dt(stage: .render, detail: "Could not build IAAdSpot"))
            return
        }
        
        load(spot: spot)
    }
    
    func loadNativeAd() {
        nativeSpot = IANativeAdSpot.build { [weak self] builder in
            builder.delegate = self
        }
        guard let nativeSpot else {
            sendNimbusError(.dt(stage: .render, detail: "Could not build IANativeAdSpot"))
            return
        }
        
        nativeSpot.loadAd(withMarkup: response.bid.adm) { [weak self] nativeAdAssets, error in
            if let error {
                self?.sendNimbusError(.dt(stage: .render, detail: error.localizedDescription))
                return
            }
            
            self?.nativeAssets = nativeAdAssets
            self?.adState = .ready
            self?.presentIfNeeded()
        }
    }
    
    func loadFullscreenAd() {
        mraidContentController = IAMRAIDContentController.build { [weak self] builder in
            builder.mraidContentDelegate = self
        }
        guard let mraidContentController else {
            sendNimbusError(.dt(stage: .render, detail: "Could not build IAMRAIDContentController"))
            return
        }
        
        videoContentController = IAVideoContentController.build { [weak self] builder in
            builder.videoContentDelegate = self
        }
        guard let videoContentController else {
            sendNimbusError(.dt(stage: .render, detail: "Could not build IAVideoContentController"))
            return
        }
        
        fullscreenController = IAFullscreenUnitController.build { [weak self] builder in
            builder.unitDelegate = self
            builder.addSupportedContentController(mraidContentController)
            builder.addSupportedContentController(videoContentController)
        }
        guard let fullscreenController else {
            sendNimbusError(.dt(stage: .render, detail: "Could not build IAFullscreenUnitController"))
            return
        }
        
        spot = IAAdSpot.build { builder in
            builder.addSupportedUnitController(fullscreenController)
        }
        guard let spot else {
            sendNimbusError(.dt(stage: .render, detail: "Could not build IAAdSpot"))
            return
        }
        
        load(spot: spot)
    }
    
    func load(spot: IAAdSpot) {
        spot.loadAd(withMarkup: response.bid.adm) { [weak self] spot, model, error in
            Task { @MainActor in
                guard let self else { return }
                
                if let error {
                    self.sendNimbusError(.dt(stage: .render, detail: error.localizedDescription))
                    return
                }
                
                self.adState = .ready
                self.presentIfNeeded()
            }
        }
    }
    
    func presentIfNeeded() {
        guard started, adState == .ready else { return }
        
        adState = .resumed
        
        switch adRenderType {
        case .banner:
            self.inlineController?.showAd(inParentView: self.adView)
        case .native:
            guard let nativeAdViewProvider = DigitalTurbineExtension.nativeAdViewProvider else {
                sendNimbusError(.dt(reason: .configuration, stage: .render, detail: "DigitalTurbineExtension.nativeAdViewProvider must be set to render native ads"))
                return
            }
            
            guard let assets = nativeAssets else {
                sendNimbusError(.dt(reason: .invalidState, stage: .render, detail: "NativeAd assets are missing"))
                return
            }
            
            let nativeView = nativeAdViewProvider(adView, assets)
            nativeView.translatesAutoresizingMaskIntoConstraints = false
            
            adView.addSubview(nativeView)
            
            NSLayoutConstraint.activate([
                nativeView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
                nativeView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
                nativeView.topAnchor.constraint(equalTo: adView.topAnchor),
                nativeView.bottomAnchor.constraint(equalTo: adView.bottomAnchor)
            ])
            
            // Set recommended tags for the views we can infer
            nativeView.tag = ViewTag.root.rawValue
            nativeView.mediaView?.tag = ViewTag.mediaView.rawValue
            nativeView.iconView?.tag = ViewTag.icon.rawValue
            
            assets.registerViewForInteraction(
                rootView: nativeView,
                mediaView: nativeView.mediaView,
                iconView: nativeView.iconView,
                clickableViews: nativeView.clickableViews
            )
            
        case .interstitial, .rewarded:
            self.fullscreenController?.showAd(animated: true)
        @unknown default:
            sendNimbusError(.dt(reason: .unsupported, stage: .render, detail: "adRenderType: \(adRenderType.rawValue)"))
        }
    }
    
    override func onStart() {
        presentIfNeeded()
    }
    
    override func onDestroy() {
        mraidContentController = nil
        mraidContentController = nil
        videoContentController = nil
        fullscreenController = nil
        inlineController = nil
        spot = nil
        nativeSpot = nil
        nativeAssets = nil
    }
    
    // MARK: - IAUnitDelegate
    
    func iaParentViewController(for unitController: IAUnitController?) -> UIViewController {
        guard let adPresentingViewController else {
            sendNimbusError(.dt(reason: .invalidState, stage: .render, detail: "No adPresentingViewController"))
            return UIViewController()
        }
        return adPresentingViewController
    }
    
    func iaAdDidExpire(_ unitController: IAUnitController?) {
        sendNimbusError(.dt(stage: .render, detail: "Ad expired"))
    }
    
    func iaAdDidReceiveClick(_ unitController: IAUnitController?) {
        sendNimbusEvent(.clicked)
    }
    
    func iaAdWillLogImpression(_ unitController: IAUnitController?) {
        sendNimbusEvent(.impression)
    }
    
    func iaUnitControllerDidDismissFullscreen(_ unitController: IAUnitController?) {
        // Avoid destroying mraid banner that presented fullscreen
        if adRenderType == .interstitial || adRenderType == .rewarded {
            destroy()
        }
    }
    
    func iaAdDidReward(_ unitController: IAUnitController?) {
        sendNimbusEvent(.rewardEarned)
    }
    
    // MARK: - IANativeAdDelegate
    
    func iaParentViewController(forAdSpot adSpot: IANativeAdSpot?) -> UIViewController {
        guard let adPresentingViewController else {
            sendNimbusError(.dt(reason: .invalidState, stage: .render, detail: "No adPresentingViewController"))
            return UIViewController()
        }
        return adPresentingViewController
    }
    
    func iaNativeAdDidExpire(_ adSpot: IANativeAdSpot?) {
        sendNimbusError(.dt(stage: .render, detail: "Native ad expired"))
    }
    
    func iaNativeAdVideoCompleted(_ adSpot: IANativeAdSpot?) {
        sendNimbusEvent(.completed)
    }
    
    func iaNativeAdWillLogImpression(_ adSpot: IANativeAdSpot?) {
        sendNimbusEvent(.impression)
    }
    
    func iaNativeAdDidReceiveClick(_ adSpot: IANativeAdSpot?, origin: String?) {
        sendNimbusEvent(.clicked)
    }
    
    func iaNativeAd(_ adSpot: IANativeAdSpot?, videoDurationUpdated videoDuration: TimeInterval) {
        storedDuration = videoDuration
    }
    
    func iaNativeAdSpot(_ adSpot: IANativeAdSpot?, didFailToLoadImageFromUrl: URL, with error: any Error) {
        sendNimbusError(.dt(stage: .render, detail: error.localizedDescription))
    }
    
    func iaNativeAd(_ adSpot: IANativeAdSpot?, videoInterruptedWithError error: any Error) {
        sendNimbusError(.dt(stage: .render, detail: error.localizedDescription))
    }
    
    // MARK: - IAMRAIDContentDelegate
    
    func iamraidContentController(_ contentController: IAMRAIDContentController?, videoInterruptedWithError error: any Error) {
        sendNimbusError(.dt(stage: .render, detail: error.localizedDescription))
    }
    
    // MARK: - IAVideoContentDelegate
    
    func iaVideoCompleted(_ contentController: IAVideoContentController?) {
        sendNimbusEvent(.completed)
    }
    
    func iaVideoContentController(_ contentController: IAVideoContentController?, videoDurationUpdated videoDuration: TimeInterval) {
        storedDuration = videoDuration
    }
    
    func iaVideoContentController(_ contentController: IAVideoContentController?, videoInterruptedWithError error: any Error) {
        sendNimbusError(.dt(stage: .render, detail: error.localizedDescription))
    }
}
