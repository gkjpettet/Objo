//
//  Klass.swift
//
//
//  Created by Garry Pettet on 11/11/2023.
//

import Foundation

public class Klass: MethodReceiver, Equatable, Hashable {
    
    // MARK: - Callbacks
    
    /// If this is a foreign class, this is the optional callback to call when the class is instantiated.
    /// (VM, the instance being instantiated as a Value, the arguments to the constructor)
    public var foreignInstantiate: ((VM, Instance, [Value]) throws -> Void)?
    
    // MARK: - Public properties
    
    /// The class's constructors. Key = arity, value = the constructor's body.
    public var constructors: [Int : Function] = [:]
    
    /// The total number of instance fields used by this class (including inherited fields).
    public let fieldCount: Int
    
    /// Stores the names of this class's fields.
    /// Only indexes `>= firstFieldIndex` are valid. This property is only used when debugging and will only be valid if the VM is running a debuggable chunk.
    public var fields: [String]
    
    /// The index in `fields` of the first of this class' fields. Lower indexes indicate the field belongs to the superclass hierarchy.
    public let firstFieldIndex: Int
    
    /// `true` if this is a foreign class.
    public let isForeign: Bool
    
    /// This class' instance methods (Key = signature, value = `Function` or `ForeignMethod`).
    public var methods: [String : Value] = [:]
    
    /// The name of this class.
    public let name: String
    
    /// This class's static fields (Key = name, value = Value).
    public var staticFields: [String :  Value] = [:]
    
    /// This class's static class methods (Key = method name, value = `Function` or `ForeignMethod`).
    public var staticMethods: [String : Value] = [:]
    
    /// This class's optional superclass.
    public var superclass: Klass? = nil
    
    /// A reference to the VM that owns this class.
    public let vm: VM
    
    // MARK: - Public methods
    public init(vm: VM, name: String, isForeign: Bool, fieldCount: Int, firstFieldIndex: Int) {
        self.vm = vm
        self.name = name
        self.isForeign = isForeign
        self.fieldCount = fieldCount
        self.firstFieldIndex = firstFieldIndex
        
        self.fields = Array(repeating: "", count: self.fieldCount)
    }
    
    // MARK: - Equatable protocol
    
    public static func == (lhs: Klass, rhs: Klass) -> Bool {
        if lhs.name == rhs.name && lhs.superclass == rhs.superclass && lhs.firstFieldIndex == rhs.firstFieldIndex && lhs.isForeign == rhs.isForeign && lhs.methods == rhs.methods && lhs.fields.elementsEqual(rhs.fields) && lhs.staticFields == rhs.staticFields && lhs.staticMethods == rhs.staticMethods && lhs.constructors == rhs.constructors {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Hashable protocol
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(isForeign)
        hasher.combine(fields)
        hasher.combine(fieldCount)
        hasher.combine(firstFieldIndex)
        hasher.combine(methods)
        hasher.combine(staticFields)
        hasher.combine(staticMethods)
    }
}
