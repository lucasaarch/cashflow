//
//  Item.swift
//  CashFlow
//
//  Created by Lucas Arch on 16/06/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
