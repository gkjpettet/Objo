//
//  Disassembler.swift
//
//
//  Created by Garry Pettet on 09/11/2023.
//

import Foundation

public struct Disassembler {
    // MARK: - Private constants
    
    /// The width a standard column in the disassembly output.
    private let COLUMN_WIDTH = 10
    
    // MARK: - Public methods
    
    /// Disassembles a function into a multiline string.
    public func disassembleFunction(function: Function) throws -> String {
        var offset = 0
        var result: [String] = []
        while offset < function.chunk.length {
            try result.append(disassembleInstruction(chunk: function.chunk, offset: &offset))
        }
        
        return result.joined(separator: "\n")
    }
    
    /// Reads the instruction at `offset` from `chunk` and returns it as a string.
    /// Mutates `offset` to point to the next instruction.
    public func disassembleInstruction(chunk: Chunk, offset: inout Int) throws -> String {
        if offset < 0 || offset >= chunk.code.count {
            throw DisassemblerError.invalidOffset(offset: offset)
        }
        
        guard let opcode = Opcode(rawValue: chunk.code[offset]) else {
            throw DisassemblerError.invalidOpcodeRawValue(value: chunk.code[offset], offset: offset)
        }
        
        switch opcode {
        case .constant, .constantLong, .defineGlobal, .defineGlobalLong, .getGlobal, .getGlobalLong, .getStaticField, .getStaticFieldLong, .setGlobal, .setGlobalLong, .setStaticField, .setStaticFieldLong:
            return try constantInstruction(opcode: opcode, chunk: chunk, offset: &offset)
            
        case .add, .add1, .assert, .bitwiseAnd, .bitwiseOr, .bitwiseXor, .breakpoint, .defineNothing, .divide, .equal, .exit, .false_, .greater, .greaterEqual, .inherit, .is_, .keyValue, .less, .lessEqual, .load0, .load1, .load2, .loadMinus1, .loadMinus2, .logicalXor, .multiply, .modulo, .negate, .not, .notEqual, .nothing, .pop, .return_, .rangeExclusive, .rangeInclusive, .shiftLeft, .shiftRight, .subtract, .subtract1, .swap, .true_:
            return simpleInstruction(opcode: opcode, offset: &offset)
            
        case .call, .constructor, .getLocalClass, .list, .map, .popN, .getLocal, .setLocal:
            return instruction8bitOperand(opcode: opcode, chunk: chunk, offset: &offset)
            
        case .class_:
            return classInstruction(chunk: chunk, offset: &offset)
            
        case.debugFieldName:
            return debugFieldName(chunk: chunk, offset: &offset)
            
        case .getField, .setField:
            return fieldInstruction(opcode: opcode, chunk: chunk, offset: &offset)
            
        case .invoke, .invokeLong:
            return invokeInstruction(opcode: opcode, chunk: chunk, offset: &offset)
            
        case .jump, .jumpIfFalse, .jumpIfTrue:
            return jumpInstruction(opcode: opcode, negative: false, chunk: chunk, offset: &offset)
            
        case .localVarDeclaration:
            return localVarDeclaration(chunk: chunk, offset: &offset)
            
        case .loop:
            return jumpInstruction(opcode: opcode, negative: true, chunk: chunk, offset: &offset)
            
        case .method, .foreignMethod:
            return methodInstruction(opcode: opcode, chunk: chunk, offset: &offset)
            
        case .superConstructor:
            return superConstructor(chunk: chunk, offset: &offset)
            
        case .superInvoke:
            return superInvoke(chunk: chunk, offset: &offset)
            
        case .superSetter:
            return superSetter(chunk: chunk, offset: &offset)
            
        default:
            throw DisassemblerError.unknownOpcode(opcode: opcode, offset: offset)
        }
    }
    
    // MARK: - Private methods
    
    /// Returns the details of a constant loading instruction at `offset`/
    /// Increments `offset` to point to the next instruction.
    ///
    /// Some instructions use a single byte operand, others use a two byte operand. The operand is the index of the constant in the constant pool.
    /// Format:
    /// `INSTRUCTION_NAME  POOL_INDEX  CONSTANT_VALUE`
    private func constantInstruction(opcode: Opcode, chunk: Chunk, offset: inout Int) throws -> String {
        var name = String(describing: opcode).replacingOccurrences(of: "_", with: "")
        
       // Get the index of the constant.
        var constantIndex: Int
        
        switch opcode {
        case .constant, .defineGlobal, .getGlobal, .setGlobal, .setField, .setStaticField,
                .getField, .getStaticField:
            constantIndex = Int(chunk.readByte(offset: offset + 1))
            offset += 2
            
        case .constantLong, .defineGlobalLong, .getGlobalLong, .setGlobalLong, .constructor,
                .setStaticFieldLong, .getStaticFieldLong:
            constantIndex = Int(chunk.readUInt16(offset: offset + 1))
            offset += 3
            
        case .class_:
            constantIndex = Int(chunk.readUInt16(offset: offset + 1))
            let isForeign = chunk.readByte(offset: offset + 3) == 1 ? true : false
            name = "\(name)\(isForeign ? " (foreign)" : "")"
            offset += 4
            
        default:
            throw DisassemblerError.unknownConstantOpcode(offset: offset)
        }
        
        // The instruction's name.
        var details = name.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Its index in the constant table.
        let indexCol = String(format: "%05d", constantIndex)
        details = details + indexCol.padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // The constant's value as a string.
        guard let constant = chunk.constants[constantIndex] else {
            throw DisassemblerError.invalidConstantIndex(offset: offset)
        }
        details = details + constant.description
        
        return details
    }
    
    /// Returns the details of an instruction (at `offset`) that takes a single byte operand
    /// Increments `offset` to point to the next instruction.
    ///
    /// Format:
    /// `INSTRUCTION_NAME  OPERAND_VALUE`
    private func instruction8bitOperand(opcode: Opcode, chunk: Chunk, offset: inout Int) -> String {
        // The instruction's name.
        let name = String(describing: opcode).replacingOccurrences(of: "_", with: "").padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the operand's value.
        let operand = chunk.readByte(offset: offset + 1)
        let details = name + String(operand).padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        offset += 2
        
        return details
    }
    
    /// Returns the details of a simple instruction at `offset`
    /// Increments `offset` to point to the next instruction.
    ///
    /// Simple instructions are a single byte and take no operands.
    /// Format:
    /// `INSTRUCTION_NAME`
    private func simpleInstruction(opcode: Opcode, offset: inout Int) -> String {
        var name = String(describing: opcode).replacingOccurrences(of: "_", with: "")
        offset += 1
        return name.padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
    }
}
