//
//  Double+Utilities.swift
//
//
//  Created by Garry Pettet on 16/11/2023.
//

import Foundation

extension Double {
    /// true if this double is an integer.
    var isInteger: Bool {
        return Int(exactly: self) != nil
    }
}
