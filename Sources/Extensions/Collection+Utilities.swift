//
//  Collection+Utilities.swift
//
//
//  Created by Garry Pettet on 01/11/2023.
//

import Foundation

extension Collection {
    /// Returns the element at `i` or `nil` if `i` is out of bounds.
    subscript(safelyIndex: i: Index) -> Element? {
        get {
            guard self.indices.contains(i) else { return nil }
            return self[i]
        }
    }
}
