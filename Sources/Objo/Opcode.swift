//
//  Opcode.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//

import Foundation

public enum Opcode: UInt8 {    
    case defineGlobal
    case defineGlobalLong
    case getLocal
    case return_
    case nothing
}
