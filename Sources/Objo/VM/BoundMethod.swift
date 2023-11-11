//
//  BoundMethod.swift
//
//
//  Created by Garry Pettet on 11/11/2023.
//

import Foundation

public struct BoundMethod: Equatable, Hashable {
    /// `true` if this is a foreign method or `false` if it's native Objo code.
    public let isForeign: Bool
    
    /// `true` if this is a static method or `false` if it's an instance method.
    public let isStatic: Bool
    
    /// If `isForeign` then this is a `ForeignMethod`, otherwise it's a `Function`.
    public let method: Method
    
    /// The class or instance this method is bound to.
    public let receiver: MethodReceiver
    
    /// A string representation of this bound method.
    public var stringValue: String {
        if isForeign {
            return (method as! ForeignMethod).stringValue
        } else {
            return (method as! Function).signature
        }
    }
    
    public init(receiver: MethodReceiver, method: Method, isStatic: Bool, isForeign: Bool) {
        self.receiver = receiver
        self.method = method
        self.isStatic = isStatic
        self.isForeign = isForeign
    }
    
    // MARK: - Equatable protocol
    
    public static func == (lhs: BoundMethod, rhs: BoundMethod) -> Bool {
        if lhs.isForeign == rhs.isForeign && lhs.isStatic == rhs.isStatic {
            // Compare methods.
            if lhs.method is ForeignMethod && rhs.method is ForeignMethod {
                return (lhs.method as! ForeignMethod) == (rhs.method as! ForeignMethod)
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    // MARK: - Hashable protocol
    public func hash(into hasher: inout Hasher) {
        hasher.combine(isForeign)
        hasher.combine(isStatic)
        if method is ForeignMethod {
            hasher.combine(method as! ForeignMethod)
        } else if method is Function {
            hasher.combine(method as! Function)
        }
    }
}
