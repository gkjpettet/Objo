//
//  Character+Utilities.swift
//
//  Useful helper extensions on the Character class.
//
//  Created by Garry Pettet on 27/10/2023.
//

import Foundation

extension Character {
    
    /// Returns a new Character instance from a Unicode codepoint.
    init?(codepoint: UInt32) {
        guard let c = Unicode.Scalar(codepoint) else {
            return nil
        }
        self = Character(c)
    }
    
    /// Returns `true` if this character is an ASCII letter.
    func isASCIILetter() -> Bool {
        if !self.isASCII { return false }
        
        if let ucase = self.unicodeScalars.first, (65...90).contains(ucase.value) {
            return true
        } else if let lcase = self.unicodeScalars.first, (97...122).contains(lcase.value) {
            return true
        } else {
            return false
        }
    }
    
    /// Returns `true` if this character is an ASCII letter, digit (0-9) or the underscore.
    func isASCIILetterDigitOrUnderscore() -> Bool {
        return self.isDigitOrUnderscore() || self.isASCIILetter()
    }
    
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
