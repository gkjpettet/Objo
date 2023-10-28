//
//  Character+Utilities.swift
//
//  Useful helper extensions on the Character class.
//
//  Created by Garry Pettet on 27/10/2023.
//

import Foundation

extension Character {
    
    /// Returns `true` if this character is "0" or "1".
    func isBinaryDigit() -> Bool {
        return self == "0" || self == "1"
    }
    
    /// Returns `true` if this character is a digit 0-9 (ASCII range 48-57).
    func isDigit() -> Bool {
        if !self.isASCII { return false }
        
        if let scalar = self.unicodeScalars.first, (48...57).contains(scalar.value) {
            return true
        } else {
            return false
        }
    }
    
    /// Returns `true` if this character is a digit or an underscore (`_`).
    func isDigitOrUnderscore() -> Bool {
        return (self.isDigit() || self == "_")
    }
}
