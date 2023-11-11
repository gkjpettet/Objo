//
//  ForeignMethod.swift
//
//
//  Created by Garry Pettet on 11/11/2023.
//

import Foundation

public struct ForeignMethod: Method, Equatable, Hashable {
    /// A unique identifier for this foreign method. Used to determine quality.
    private let id: UUID
    
    /// The number of arguments this foreign method requires.
    public let arity: Int
    
    /// The native callback to invoke when this foreign method is called.
    public let method: (VM) -> Void
    
    /// This foreign method's signature.
    public let signature: String
    
    /// A string representation of this foreign method.
    public var stringValue: String { return "foreign \(signature)" }
    
    public init(signature: String, arity: Int, uuid: UUID, method: @escaping (VM) -> Void) {
        self.signature = signature
        self.arity = arity
        self.id = uuid
        self.method = method
    }
    
    // MARK: - Equatable protocol
    
    public static func == (lhs: ForeignMethod, rhs: ForeignMethod) -> Bool {
        if lhs.arity == rhs.arity && lhs.signature == rhs.signature && lhs.id == rhs.id {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Hashable protocol
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(signature)
    }
}
