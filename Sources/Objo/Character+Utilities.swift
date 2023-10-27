//
//  Character+Utilities.swift
//
//  Useful helper extensions on the Character class.
//
//  Created by Garry Pettet on 27/10/2023.
//

import Foundation

extension Character {
    /// Returns `true` if this character is a digit or an underscore (`_`).
    func isDigitOrUnderscore() -> Bool {
        return (self.isNumber || self == "_")
    }
}
