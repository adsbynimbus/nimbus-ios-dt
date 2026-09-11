//
//  DTRequestBridge.swift
//  NimbusDTKit
//  Created on 5/27/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import IASDKCore
import NimbusKit

protocol DTRequestBridgeType: Sendable {
    @concurrent func bidToken() async throws -> String
}

final class DTRequestBridge: DTRequestBridgeType {
    init() {}
    
    @concurrent func bidToken() async throws -> String {
        guard let token = FMPBiddingManager.sharedInstance().biddingToken() else {
            throw NimbusError.dt(stage: .request, detail: "Bidding token was not returned")
        }
        
        return token
    }
}
