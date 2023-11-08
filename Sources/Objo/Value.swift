//
//  Value.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//

import Foundation

public enum Value: Hashable {
    case boolean(Bool)
    case nothing
    case number(Double)
    case string(String)
}
