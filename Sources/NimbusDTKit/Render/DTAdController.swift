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
//
// Threading: DT invokes delegate callbacks and completion blocks on arbitrary queues
// (e.g. image-load failures arrive on the NSURLSession delegate queue). Conformances are
// explicitly nonisolated so every function must be nonisolated and hop to the main actor itself.
final class DTAdController: AdController,
                            nonisolated IAUnitDelegate,
                            nonisolated IANativeAdDelegate,
                            nonisolated IAMRAIDContentDelegate,
                            nonisolated IAVideoContentDelegate {
    
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
    
    func buildBannerAdSpot() throws(NimbusError) -> IAAdSpot {
        mraidContentController = IAMRAIDContentController.build { [weak self] builder in
            builder.mraidContentDelegate = self
        }
        guard let mraidContentController else {
            throw .dt(stage: .render, detail: "Could not build IAMRAIDContentController")
        }
        
        inlineController = IAViewUnitController.build { [weak self] builder in
            builder.unitDelegate = self
            builder.addSupportedContentController(mraidContentController)
        }
        guard let inlineController else {
            throw .dt(stage: .render, detail: "Could not build IAViewUnitController")
        }
        
        spot = IAAdSpot.build { builder in
            builder.addSupportedUnitController(inlineController)
        }
        guard let spot else {
            throw .dt(stage: .render, detail: "Could not build IAAdSpot for banner ad")
        }
        
        return spot
    }
    
    func loadBannerAd() {
        do {
            let spot = try buildBannerAdSpot()
            load(spot: spot)
        } catch {
            sendNimbusError(error)
        }
    }
    
    func buildNativeAdSpot() throws(NimbusError) -> IANativeAdSpot {
        nativeSpot = IANativeAdSpot.build { [weak self] builder in
            builder.delegate = self
        }
        guard let nativeSpot else {
            throw .dt(stage: .render, detail: "Could not build IANativeAdSpot")
        }
        
        return nativeSpot
    }
    
    func loadNativeAd() {
        do {
            let nativeSpot = try buildNativeAdSpot()
            
            // @Sendable: stops the closure from inheriting main-actor isolation. DT's completion
            // isn't annotated, so we can't trust which queue it arrives on; hop explicitly instead.
            nativeSpot.loadAd(withMarkup: response.bid.adm) { @Sendable [weak self] nativeAdAssets, error in
                guard let self else { return }
                
                // Handed to the main actor once and never touched again on this side.
                nonisolated(unsafe) let assets = nativeAdAssets
                let errorDetail = error?.localizedDescription
                
                self.runOnMainActor {
                    if let errorDetail {
                        self.sendNimbusError(.dt(stage: .render, detail: errorDetail))
                        return
                    }
                    
                    self.nativeAssets = assets
                    self.adState = .ready
                    self.presentIfNeeded()
                }
            }
        } catch {
            sendNimbusError(error)
        }
    }
    
    func buildFullscreenAdSpot() throws(NimbusError) -> IAAdSpot {
        mraidContentController = IAMRAIDContentController.build { [weak self] builder in
            builder.mraidContentDelegate = self
        }
        guard let mraidContentController else {
            throw .dt(stage: .render, detail: "Could not build IAMRAIDContentController")
        }
        
        videoContentController = IAVideoContentController.build { [weak self] builder in
            builder.videoContentDelegate = self
        }
        guard let videoContentController else {
            throw .dt(stage: .render, detail: "Could not build IAVideoContentController")
        }
        
        fullscreenController = IAFullscreenUnitController.build { [weak self] builder in
            builder.unitDelegate = self
            builder.addSupportedContentController(mraidContentController)
            builder.addSupportedContentController(videoContentController)
        }
        guard let fullscreenController else {
            throw .dt(stage: .render, detail: "Could not build IAFullscreenUnitController")
        }
        
        spot = IAAdSpot.build { builder in
            builder.addSupportedUnitController(fullscreenController)
        }
        guard let spot else {
            throw .dt(stage: .render, detail: "Could not build IAAdSpot")
        }
        
        return spot
    }
    
    func loadFullscreenAd() {
        do {
            let spot = try buildFullscreenAdSpot()
            load(spot: spot)
        } catch {
            sendNimbusError(error)
        }
    }
    
    func load(spot: IAAdSpot) {
        // @Sendable for the same reason as loadNativeAd(): an inherited @MainActor closure would be
        // checked on entry, before any inner hop could run.
        spot.loadAd(withMarkup: response.bid.adm) { @Sendable [weak self] _, _, error in
            guard let self else { return }
            
            let errorDetail = error?.localizedDescription
            
            self.runOnMainActor {
                if let errorDetail {
                    self.sendNimbusError(.dt(stage: .render, detail: errorDetail))
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
        videoContentController = nil
        fullscreenController = nil
        inlineController = nil
        spot = nil
        nativeSpot = nil
        nativeAssets = nil
    }
    
    // MARK: - IAUnitDelegate
    
    nonisolated func iaParentViewController(for unitController: IAUnitController?) -> UIViewController {
        onMainSync { self.presentingViewControllerOrError() }
    }
    
    nonisolated func iaAdDidExpire(_ unitController: IAUnitController?) {
        runOnMainActor { self.sendNimbusError(.dt(stage: .render, detail: "Ad expired")) }
    }
    
    nonisolated func iaAdDidReceiveClick(_ unitController: IAUnitController?) {
        runOnMainActor { self.sendNimbusEvent(.clicked) }
    }
    
    nonisolated func iaAdWillLogImpression(_ unitController: IAUnitController?) {
        runOnMainActor { self.sendNimbusEvent(.impression) }
    }
    
    nonisolated func iaUnitControllerDidDismissFullscreen(_ unitController: IAUnitController?) {
        runOnMainActor {
            // Avoid destroying mraid banner that presented fullscreen
            if self.adRenderType == .interstitial || self.adRenderType == .rewarded {
                self.destroy()
            }
        }
    }
    
    nonisolated func iaAdDidReward(_ unitController: IAUnitController?) {
        runOnMainActor { self.sendNimbusEvent(.rewardEarned) }
    }
    
    // MARK: - IANativeAdDelegate
    
    nonisolated func iaParentViewController(forAdSpot adSpot: IANativeAdSpot?) -> UIViewController {
        onMainSync { self.presentingViewControllerOrError() }
    }
    
    nonisolated func iaNativeAdDidExpire(_ adSpot: IANativeAdSpot?) {
        runOnMainActor { self.sendNimbusError(.dt(stage: .render, detail: "Native ad expired")) }
    }
    
    nonisolated func iaNativeAdVideoCompleted(_ adSpot: IANativeAdSpot?) {
        runOnMainActor { self.sendNimbusEvent(.completed) }
    }
    
    nonisolated func iaNativeAdWillLogImpression(_ adSpot: IANativeAdSpot?) {
        runOnMainActor { self.sendNimbusEvent(.impression) }
    }
    
    nonisolated func iaNativeAdDidReceiveClick(_ adSpot: IANativeAdSpot?, origin: String?) {
        runOnMainActor { self.sendNimbusEvent(.clicked) }
    }
    
    nonisolated func iaNativeAd(
        _ adSpot: IANativeAdSpot?,
        videoDurationUpdated videoDuration: TimeInterval
    ) {
        runOnMainActor { self.storedDuration = videoDuration }
    }
    
    nonisolated func iaNativeAdSpot(
        _ adSpot: IANativeAdSpot?,
        didFailToLoadImageFromUrl: URL,
        with error: any Error
    ) {
        runOnMainActor { self.sendNimbusError(.dt(stage: .render, detail: error.localizedDescription)) }
    }
    
    nonisolated func iaNativeAd(_ adSpot: IANativeAdSpot?, videoInterruptedWithError error: any Error) {
        runOnMainActor { self.sendNimbusError(.dt(stage: .render, detail: error.localizedDescription)) }
    }
    
    // MARK: - IAMRAIDContentDelegate
    
    nonisolated func iamraidContentController(
        _ contentController: IAMRAIDContentController?,
        videoInterruptedWithError error: any Error
    ) {
        runOnMainActor { self.sendNimbusError(.dt(stage: .render, detail: error.localizedDescription)) }
    }
    
    // MARK: - IAVideoContentDelegate
    
    nonisolated func iaVideoCompleted(_ contentController: IAVideoContentController?) {
        runOnMainActor { self.sendNimbusEvent(.completed) }
    }
    
    nonisolated func iaVideoContentController(
        _ contentController: IAVideoContentController?,
        videoDurationUpdated videoDuration: TimeInterval
    ) {
        runOnMainActor { self.storedDuration = videoDuration }
    }
    
    nonisolated func iaVideoContentController(
        _ contentController: IAVideoContentController?,
        videoInterruptedWithError error: any Error
    ) {
        runOnMainActor { self.sendNimbusError(.dt(stage: .render, detail: error.localizedDescription)) }
    }
    
    // MARK: - Helpers
    
    private func presentingViewControllerOrError() -> UIViewController {
        guard let adPresentingViewController else {
            sendNimbusError(.dt(reason: .invalidState, stage: .render, detail: "No adPresentingViewController"))
            return UIViewController()
        }
        return adPresentingViewController
    }
    
    /// Synchronous main-actor hop for delegate methods that must return a value.
    private nonisolated func onMainSync<T: Sendable>(_ body: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(body)
        } else {
            return DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
        }
    }
}
