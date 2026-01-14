//
//  Item.swift
//  SvenSwipe
//
//  Created by Nico Stillhart on 14.01.2026.
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
