//
//  Chunk.swift
//
//
//  Created by Garry Pettet on 08/11/2023.
//

import Foundation

public struct Chunk {
    // MARK: - Static constants
    
    /// The maximum permissible index of a constant in a chunk's constant pool.
    public static let MAX_CONSTANTS = 65534
    
    // MARK: - Private properties
    
    /// Stores the line number for the corresponding byte in `code`.
    private var lines: [Int] = []
    
    /// Stores the script ID for the corresponding byte in `code`. Defaults to `0`.
    private var scriptID: [Int] = []
    
    // MARK: - Public properties
    
    /// This chunk's raw bytecode.
    public var code: [UInt8] = []
    
    /// This chunks constants table.
    public var constants = ConstantTable()
    
    /// The number of bytes of code in the chunk.
    public var length: Int { return code.count }
    
    // MARK: - Private properties
    
    /// `true` if this chunk was compiled for debugging (reduced performance compared to production).
    private let isDebug: Bool
    
    // MARK: - Public methods
    
    /// - Parameter isDebug: `true` if this chunk will be compiled for debugging.
    public init(isDebug: Bool) {
        self.isDebug = isDebug
    }
    
    /// Writes a byte to this chunk.
    ///
    /// - Parameter token: The parser token that generated this byte of data.
    mutating public func writeByte(_ byte: UInt8, token: Token) {
        code.append(byte)
        lines.append(token.line)
        scriptID.append(token.scriptId)
    }
    
    /// Writes an opcode to this chunk.
    ///
    /// - Parameter token: The parser token that generated this opcode.
    mutating public func writeOpcode(_ opcode: Opcode, token: Token) {
        code.append(opcode.rawValue)
        lines.append(token.line)
        scriptID.append(token.scriptId)
    }
    
    /// Writes an unsigned 16-bit integer to this chunk's bytecode array.
    ///
    /// - Parameter token: The parser token that generated this byte of data.
    /// The integer is written in big endian format (most significant byte first).
    /// We write the high byte, then the low byte.
    mutating public func writeUInt16(_ i16: UInt16, token: Token) {
        let msb = UInt8((i16 & 0xFF00) >> 8)
        let lsb = UInt8(i16 & 0x00FF)
        code.append(msb)
        code.append(lsb)
        
        // Write twice as we're writing two bytes.
        lines.append(token.line)
        lines.append(token.line)
        scriptID.append(token.scriptId)
        scriptID.append(token.scriptId)
    }
}
