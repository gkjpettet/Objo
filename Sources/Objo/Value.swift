//
//  Value.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//

import Foundation

public enum Value: CustomStringConvertible, Hashable {    
    case boolean(Bool)
    case boundMethod(BoundMethod)
    case foreignMethod(ForeignMethod)
    case function(Function)
    case instance(Instance)
    case klass(Klass)
    case nothing(Nothing)
    case number(Double)
    case string(String)
    
    public var description: String {
        switch self {
        case .boolean(let b):
            return b ? "true" : "false"
            
        case .boundMethod(let bm):
            return bm.stringValue
            
        case .foreignMethod(let fm):
            return fm.signature
            
        case .function(let f):
            return f.signature
            
        case .instance(let i):
            return i.name
            
        case .klass(let k):
            return k.name
            
        case .nothing:
            return "nothing"
            
        case .number(let d):
            return String(d)
            
        case .string(let s):
            return s
        }
    }
}
