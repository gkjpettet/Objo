//
//  DisassemblerError.swift
//
//
//  Created by Garry Pettet on 09/11/2023.
//

import Foundation

public enum DisassemblerError: Error {
    case invalidConstantIndex(offset: Int)
    case invalidOffset(offset: Int)
    case invalidOpcodeRawValue(value: UInt8, offset: Int)
    case unknownConstantOpcode(offset: Int)
    case unknownOpcode(opcode: Opcode, offset: Int)
}
