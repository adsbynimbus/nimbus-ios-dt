//
//  DTRequestInterceptor.swift
//  NimbusDTKit
//  Created on 5/27/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Foundation
import NimbusKit

final class DTRequestInterceptor {
    
    /// Bridge that communicates with Digital Turbine SDK
    private let bridge: DTRequestBridgeType
    
    init(bridge: DTRequestBridgeType = DTRequestBridge()) {
        self.bridge = bridge
    }
}

extension DTRequestInterceptor: NimbusRequest.Interceptor {
    public func modifyRequest(request: NimbusRequest) async throws -> [NimbusRequest.Delta] {
        let bidToken = try await bridge.bidToken()
        try Task.checkCancellation()
        
        return [.init(target: .user, key: "digital_turbine_buyeruid", value: bidToken)]
    }
}
