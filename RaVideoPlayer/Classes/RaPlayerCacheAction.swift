//
//  RaPlayerCacheAction.swift
//  RaVideoPlayer
//
//  Created by Ouch Kemvanra on 12/30/21.
//

import Foundation

public enum RaPlayerCacheActionType: Int {
    case local
    case remote
}

public struct RaPlayerCacheAction: Hashable, CustomStringConvertible {
    public var type: RaPlayerCacheActionType
    public var range: NSRange
    
    public var description: String {
        return "type: \(type)  range:\(range)"
    }
    
    public var hashValue: Int {
        return String(format: "%@%@", NSStringFromRange(range), String(describing: type)).hashValue
    }
    
    public static func ==(lhs: RaPlayerCacheAction, rhs: RaPlayerCacheAction) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    
    init(type: RaPlayerCacheActionType, range: NSRange) {
        self.type = type
        self.range = range
    }
    
}
