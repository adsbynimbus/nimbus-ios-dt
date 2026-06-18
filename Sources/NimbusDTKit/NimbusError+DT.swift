//
//  NimbusError+DT.swift
//  NimbusDTKit
//
//  Created on 5/27/26.
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit

extension NimbusError.Domain {
    static let dt = Self(rawValue: "digitalturbine")
}

extension NimbusError {
    static func dt(reason: Reason = .failure, stage: Stage, detail: String? = nil) -> NimbusError {
        NimbusError(reason: reason, domain: .dt, stage: stage, detail: detail)
    }
}
