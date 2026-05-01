//
//  Item.swift
//  SwiftUI Web Image Picker
//
//  Created by Nathan Fennel on 5/1/26.
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
