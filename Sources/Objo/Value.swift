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
            
        case .number(let d):
            return String(d)
            
        case .string(let s):
            return s
        }
    }
    
    /// Returns the type (class name) of this value. Will be nil for bound and foreign methods.
    public var type: String? {
        switch self {
        case .boolean:
            return "Boolean"
            
        case .boundMethod, .foreignMethod:
            return nil
            
        case .function:
            return "Function"
            
        case .instance(let instance):
            return instance.klass.name
            
        case .klass(let klass):
            return klass.name
            
        case .number:
            return "Number"
            
        case .string:
            return "String"
        }
    }
}
