//
//  Item.swift
//  PDCA工具
//
//  Created by 邮费 on 2026/3/24.
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
