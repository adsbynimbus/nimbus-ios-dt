//
//  DTAdControllerTests.swift
//  NimbusDTKit
//  Created on 9/30/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Testing
@testable import NimbusKit
@testable import NimbusDTKit
import UIKit

@Suite("Digital Turbine AdController tests")
@MainActor
struct DTAdControllerTests {
    @Test func bannerAdEventsGetFired() throws {
        let container = UIView()
        let controller = UIViewController()
        let adController = DTAdController(
            response: .init(id: "", bid: .init(mtype: .static, adm: "", price: 0, ext: .init())),
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: controller
        )
        let delegate = MockDelegate()
        adController.delegate = delegate
        adController.adState = .ready
        _ = try! adController.buildBannerAdSpot()
        
        #expect(adController.videoContentController == nil)
        #expect(adController.fullscreenController == nil)
        #expect(adController.nativeSpot == nil)
                
        let unit = try #require(adController.inlineController)
        let dt = try #require(unit.unitDelegate, "unitDelegate not wired")
        
        dt.iaAdWillLogImpression?(unit)
        #expect(delegate.events == [.impression])
        
        dt.iaAdDidReceiveClick?(unit)
        #expect(delegate.events == [.impression, .clicked])
        #expect(delegate.lastError == nil)
        #expect(dt.iaParentViewController(for: unit) == controller)
        
        let mraid = try #require(adController.mraidContentController)
        let mraidDelegate = try #require(mraid.mraidContentDelegate)
        
        mraidDelegate.iamraidContentController?(
            mraid, videoInterruptedWithError: NSError(domain: "digitalturbine", code: 123)
        )
        
        #expect(delegate.lastError != nil)
        #expect(delegate.events.last == .destroyed)
    }
    
    @Test func nativeAdEventsGetFired() throws {
        let container = UIView()
        let controller = UIViewController()
        let adController = DTAdController(
            response: .init(id: "", bid: .init(mtype: .native, adm: "", price: 0, ext: .init())),
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: controller
        )
        let delegate = MockDelegate()
        adController.delegate = delegate
        adController.adState = .ready
        _ = try! adController.buildNativeAdSpot()
        
        #expect(adController.videoContentController == nil)
        #expect(adController.fullscreenController == nil)
        #expect(adController.inlineController == nil)
        
        let unit = try #require(adController.nativeSpot)
        let dt = try #require(unit.delegate, "native delegate not wired")
        
        dt.iaNativeAdWillLogImpression?(unit)
        #expect(delegate.events == [.impression])
        
        dt.iaNativeAdDidReceiveClick?(unit, origin: nil)
        #expect(delegate.events == [.impression, .clicked])
        #expect(delegate.lastError == nil)
        #expect(dt.iaParentViewController(forAdSpot: unit) == controller)
        
        dt.iaNativeAdDidExpire?(unit)
        #expect(delegate.lastError != nil)
        #expect(delegate.events.last == .destroyed)
    }
    
    @Test func interstitialAdEventsGetFired() throws {
        let container = UIView()
        let controller = UIViewController()
        let adController = DTAdController(
            response: .init(id: "", bid: .init(mtype: .static, adm: "", price: 0, ext: .init())),
            isBlocking: true,
            isRewarded: false,
            container: container,
            adPresentingViewController: controller
        )
        let delegate = MockDelegate()
        adController.delegate = delegate
        _ = try! adController.buildFullscreenAdSpot()
        
        #expect(adController.inlineController == nil)
        #expect(adController.nativeSpot == nil)
        
        let unit = try #require(adController.fullscreenController)
        let dt = try #require(unit.unitDelegate, "unitDelegate not wired")
        
        dt.iaAdWillLogImpression?(unit)
        #expect(delegate.events == [.impression])
        
        dt.iaAdDidReceiveClick?(unit)
        #expect(delegate.events == [.impression, .clicked])
        #expect(delegate.lastError == nil)
        #expect(dt.iaParentViewController(for: unit) == controller)
        
        let video = try #require(adController.videoContentController)
        
        let videoDelegate = try #require(video.videoContentDelegate)
        videoDelegate.iaVideoCompleted?(video)
        #expect(delegate.events.last == .completed)
        
        videoDelegate.iaVideoContentController?(video, videoDurationUpdated: 30)
        #expect(adController.adDuration == 30)
        
        dt.iaUnitControllerDidDismissFullscreen?(unit)
        
        #expect(delegate.lastError == nil)
        #expect(delegate.events.last == .destroyed)
    }
    
    @Test func rewardedAdEventsGetFired() throws {
        let container = UIView()
        let controller = UIViewController()
        let adController = DTAdController(
            response: .init(id: "", bid: .init(mtype: .video, adm: "", price: 0, ext: .init())),
            isBlocking: true,
            isRewarded: true,
            container: container,
            adPresentingViewController: controller
        )
        let delegate = MockDelegate()
        adController.delegate = delegate
        _ = try! adController.buildFullscreenAdSpot()
        
        let unit = try #require(adController.fullscreenController)
        let dt = try #require(unit.unitDelegate, "unitDelegate not wired")
        
        dt.iaAdWillLogImpression?(unit)
        #expect(delegate.events == [.impression])
        
        dt.iaAdDidReceiveClick?(unit)
        #expect(delegate.events == [.impression, .clicked])
        #expect(delegate.lastError == nil)
        #expect(dt.iaParentViewController(for: unit) == controller)
        
        let video = try #require(adController.videoContentController)
        
        let videoDelegate = try #require(video.videoContentDelegate)
        videoDelegate.iaVideoCompleted?(video)
        #expect(delegate.events.last == .completed)
        
        dt.iaAdDidReward?(unit)
        #expect(delegate.events.last == .rewardEarned)
        
        videoDelegate.iaVideoContentController?(video, videoDurationUpdated: 30)
        #expect(adController.adDuration == 30)
        
        dt.iaUnitControllerDidDismissFullscreen?(unit)
        
        #expect(delegate.lastError == nil)
        #expect(delegate.events.last == .destroyed)
        
        #expect(adController.inlineController == nil)
        #expect(adController.nativeSpot == nil)
    }
}

class MockDelegate: AdController.Delegate {
    var events: [AdEvent] = []
    var lastError: NimbusError?
    
    func didReceiveNimbusEvent(event: NimbusKit.AdEvent) {
        events.append(event)
    }
    
    func didReceiveNimbusError(error: NimbusKit.NimbusError) {
        lastError = error
    }
}
