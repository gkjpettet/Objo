//
//  Instance.swift
//
//
//  Created by Garry Pettet on 11/11/2023.
//

import Foundation

public class Instance: MethodReceiver, Equatable, Hashable {
    // MARK: - Public properties
    
    /// This instance's fields. Lower indexes may be fields utilised by superclasses.
    public var fields: [Value] = []
    
    /// If this is an instance of a foreign class, this is used to store any instance data. It's only accessed by the host application. The VM ignores it.
    public var foreignData: Any?
    
    /// A reference to this instance's class.
    public let klass: Klass
    
    /// This instance's name.
    public let name: String
    
    // MARK: - Public methods
    
    public init(klass: Klass) {
        self.klass = klass
        self.name = self.klass.name + " instance"
        
        // This instance's fields are initialised to `nothing` **unless** this is a nothing instance (which does not have fields).
        if klass.name != "Nothing" {
            fields = Array(repeating: .instance(klass.vm.nothing!), count: klass.fieldCount)
        }
    }
    
    // MARK: - Equatable protocol
    
    public static func == (lhs: Instance, rhs: Instance) -> Bool {
        if lhs.name == rhs.name && lhs.klass.name == rhs.klass.name && lhs.fields.count == rhs.fields.count && lhs.fields.elementsEqual(rhs.fields) {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Hashable protocol
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(klass.name)
        hasher.combine(fields)
    }
}
