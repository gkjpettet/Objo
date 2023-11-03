//
//  Objo.swift
//
//  A static class providing helpful methods for several classes in the Objo package.
//
//  Created by Garry Pettet on 03/11/2023.
//

import Foundation

public final class Objo {
    private init() {}
    
    /// Computes a function/method signature given its name and arity.
    ///
    /// Examples:
    /// ```objo
    /// greet()          -> greet()
    /// print(something) -> print(_)
    /// name=(who)       -> name=(_)
    /// add(a, b)        -> add(_,_)
    /// ```
    public static func computeSignature(name: String, arity: Int, isSetter: Bool) throws -> String {
        // Sanity check for setter methods.
        if isSetter && arity != 1 {
            throw ObjoError.invalidArgument("Setter methods must have an arity of 1 (not \(arity))")
        }
        
        // Simple case with no arguments.
        if arity == 0 { return "\(name) ()" }
        
        // Build the signature.
        var sig: [String] = [name]
        if isSetter { sig.append("=") }
        sig.append("(")
        
        for i in 1...arity {
            sig.append("_")
            if i < arity { sig.append(",") }
        }
        
        sig.append(")")
        
        return sig.joined()
    }
}
