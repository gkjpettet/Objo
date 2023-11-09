//
//  Value.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//

import Foundation

public enum Value: CustomStringConvertible, Hashable {
    case boolean(Bool)
    case nothing
    case number(Double)
    case string(String)
    
    public var description: String {
        switch self {
        case .boolean(let b):
            return b ? "true" : "false"
            
        case .nothing:
            return "nothing"
            
        case .number(let d):
            return String(d)
            
        case .string(let s):
            return s
        }
    }
}
