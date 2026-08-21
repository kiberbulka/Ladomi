//
//  AnalyticsService.swift
//  Tracker
//
//  Created by Olya on 21.05.2025.
//

import Foundation

final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    func report(event: String, screen: String, item: String? = nil) {
        var params: [AnyHashable: Any] = [
            "event": event,
            "screen": screen
        ]
        
        if let item = item {
            params["item"] = item
        }

        print("Analytics Event: \(params)")
    }
}
