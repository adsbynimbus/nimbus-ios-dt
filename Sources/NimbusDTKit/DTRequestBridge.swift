//
//  DTRequestBridge.swift
//  NimbusDTKit
//  Created on 5/27/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import IASDKCore
import NimbusKit

protocol DTRequestBridgeType: Sendable {
    func bidToken() async throws -> String
}

final class DTRequestBridge: DTRequestBridgeType {
    
    /// FMPBiddingManager isn't safe to call concurrently (crashes in FMPABTestingConfigManager),
    /// so every call is serialized here. The caller suspends instead of blocking, so this is
    /// safe from any executor, including the main actor.
    private static let queue = DispatchQueue(label: "NimbusDTKit.requestQueue")
    
    init() {}
    
    func bidToken() async throws -> String {
        let token = await withCheckedContinuation { continuation in
            Self.queue.async {
                continuation.resume(returning: FMPBiddingManager.sharedInstance().biddingToken())
            }
        }
        
        guard let token else {
            throw NimbusError.dt(stage: .request, detail: "Bidding token was not returned")
        }
        
        return token
    }
}
