//
//  Item.swift
//  jeeves
//
//  Created by wiard vasen on 28/02/2026.
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
