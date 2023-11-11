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
            
        case .add, .add1, .assert, .bitwiseAnd, .bitwiseNot, .bitwiseOr, .bitwiseXor, .breakpoint, .defineNothing, .divide, .equal, .exit, .false_, .greater, .greaterEqual, .inherit, .is_, .keyValue, .less, .lessEqual, .load0, .load1, .load2, .loadMinus1, .loadMinus2, .logicalXor, .multiply, .modulo, .negate, .not, .notEqual, .nothing, .pop, .return_, .rangeExclusive, .rangeInclusive, .shiftLeft, .shiftRight, .subtract, .subtract1, .swap, .true_:
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
            return try invokeInstruction(opcode: opcode, chunk: chunk, offset: &offset)
            
        case .jump, .jumpIfFalse, .jumpIfTrue:
            return jumpInstruction(opcode: opcode, negative: false, chunk: chunk, offset: &offset)
            
        case .localVarDeclaration:
            return localVarDeclaration(chunk: chunk, offset: &offset)
            
        case .loop:
            return jumpInstruction(opcode: opcode, negative: true, chunk: chunk, offset: &offset)
            
        case .method, .foreignMethod:
            return try methodInstruction(opcode: opcode, chunk: chunk, offset: &offset)
            
        case .superConstructor:
            return superConstructor(chunk: chunk, offset: &offset)
            
        case .superInvoke:
            return superInvoke(chunk: chunk, offset: &offset)
            
        case .superSetter:
            return superSetter(chunk: chunk, offset: &offset)
        }
    }
    
    // MARK: - Private methods
    
    /// Returns the details of a class instruction at `offset` and increments `offset` to point to the next instruction.
    ///
    /// We return the instruction's name, the index of the class's name in the constant pool, the class name, whether
    /// it's a foreign class, the total number of fields used by the class and the index of the first field in
    /// `Klass.Fields`.
    /// Format:
    /// `INSTRUCTION_NAME  POOL_INDEX  CLASS_NAME  FIELD_COUNT  FIRST_FIELD_INDEX`
    private func classInstruction(chunk: Chunk, offset: inout Int) -> String {
        // Get index of the constant.
        let constantIndex = Int(chunk.readUInt16(offset: offset + 1))
        
        // Compute the name and whether the class is foreign.
        let isForeign = chunk.readByte(offset: offset + 3) == 1 ? true : false
        let name = "class\(isForeign ? " (foreign)" : "")"
        
        // Get the number of fields.
        let fieldCount = Int(chunk.readByte(offset: offset + 4))
        
        // Get the index of the first field.
        let fieldFirstIndex = Int(chunk.readByte(offset: offset + 5))
        
        offset += 6
        
        // The instruction's name.
        var details = name.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Its index in the constant table.
        let indexCol = String(format: "%05d", constantIndex).padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
        details = details + indexCol
        
        // The class's name.
        let className = chunk.constants[constantIndex]!.description
        details = details + className.padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the field count.
        let fieldCountCol = String(fieldCount).padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
        details = details + fieldCountCol
        
        // Append the first field index.
        details = "\(details)\(fieldFirstIndex)"
        
        return details
    }
    
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
    
    /// Returns the details of the OP_DEBUG_FIELD_NAME instruction at `offset` and increments `offset` to point to the next instruction.
    ///
    /// This instruction takes a two byte (field name index) and a one byte (`Klass.fields` index) operand.
    ///
    /// Format:
    /// `FIELD_NAME  INDEX`
    private func debugFieldName(chunk: Chunk, offset: inout Int) -> String {
        var details = "debugFieldName".padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Get the index of the name of the field in the chunk's constant table.
        let tableIndex = Int(chunk.readUInt16(offset: offset + 1))
        
        // Get the `Klass.fields` index.
        let index = Int(chunk.readByte(offset: offset + 3))
        
        let fieldName = chunk.constants[tableIndex]!.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the name of the field.
        details += fieldName
        
        // Append the index.
        details += "\(index)"
        
        offset += 4
        
        return details
    }
    
    /// Returns the details of a field get/set instruction at `offset` and increments `offset` to point to the next instruction.
    ///
    /// The operand is the index of the field in the instance's `fields` array.
    /// Format:
    /// `INSTRUCTION_NAME  FIELDS_INDEX`
    private func fieldInstruction(opcode: Opcode, chunk: Chunk, offset: inout Int) -> String {
        // Get index of the constant.
        let fieldIndex = Int(chunk.readByte(offset: offset + 1))
        
        // The instruction's name.
        var details = String(describing: opcode).padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // The field index.
        let fieldIndexCol = String(format: "%05d", fieldIndex)
        details = details + fieldIndexCol
        
        offset += 2
        
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
    
    /// Returns the details of an invoke instruction at `offset` and increments `offset` to point to the next instruction.
    ///
    /// Returns the instruction's name, the constant's index in the pool, the method's signature and the argument count.
    ///
    /// Format:
    /// `INSTRUCTION  METHOD_NAME_INDEX  METHOD_NAME  ARGCOUNT`
    private func invokeInstruction(opcode: Opcode, chunk: Chunk, offset: inout Int) throws -> String {
        var index: Int
        var argCount: Int
        switch opcode {
        case .invoke:
            index = Int(chunk.readByte(offset: offset + 1))
            argCount = Int(chunk.readByte(offset: offset + 2))
            offset += 3
            
        case .invokeLong:
            index = Int(chunk.readUInt16(offset: offset + 1))
            argCount = Int(chunk.readByte(offset: offset + 3))
            offset += 4
            
        default:
            throw DisassemblerError.unknownOpcode(opcode: opcode, offset: offset)
        }
        
        // The instruction's name.
        var details = String(describing: opcode).padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the index in the pool.
        details += String(format: "%05d", index).padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the method's name.
        let methodName = chunk.constants[index]!.description
        details += methodName.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the argument count.
        let argCountString = String(argCount).padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        details += argCountString
        
        return details
    }
    
    /// Returns the details of the `localVarDeclaration` instruction at `offset`
    /// and increments `offset` to point to the next instruction.
    ///
    /// This instruction takes a two byte (name index) and a one byte (slot index) operand.
    ///
    /// Format:
    /// `VAR_NAME  SLOT`
    private func localVarDeclaration(chunk: Chunk, offset: inout Int) -> String {
        // The instruction's name.
        var details = "localVarDeclaration".padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Get the index of the name of the variable in the chunk's constant table.
        let index = Int(chunk.readUInt16(offset: offset + 1))
        
        // Get the local slot.
        let slot = chunk.readByte(offset: offset + 3)
        
        // Append the name of the variable.
        details += chunk.constants[index]!.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the slot.
        details += "\(slot)"
        
        offset += 4
        
        return details
    }
    
    /// Returns the details of a jump instruction at `offset` and increments `offset` to point to the next instruction.
    ///
    /// Jump instructions take a two byte operand (the jump offset)
    /// If `negative` then this is a backwards jump.
    ///
    /// Format:
    /// `INSTRUCTION_NAME  OFFSET -> DESTINATION`
    private func jumpInstruction(opcode: Opcode, negative: Bool, chunk: Chunk, offset: inout Int) -> String {
        // The instruction's name.
        var details = String(describing: opcode).padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the destination offset.
        let jump = Int(chunk.readUInt16(offset: offset + 1))
        let destination = offset + 3 + (negative ? -1 : 1) * jump
        let destCol = "\(offset) -> \(destination)"
        details = details + destCol.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        offset += 3
        
        return details
    }
    
    /// Returns the details of a method instruction at `offset` and increments `offset` to point to the next instruction.
    ///
    /// We return the instruction's name, the index of the method's name in the constant pool, the method name and if it's a static or instance method.
    ///
    /// The `method` instruction takes a two byte operand (for the index of the method's signature in the constant pool) and a single byte
    /// operand specifying if the method is static (1) or instance (0).
    /// The `foreignMethod` instruction first takes a two byte operand for the index of the signature in the constant pool. It then takes a single byte operand specifying the arity (we don't print this) and finally a single byte operand
    /// specifying if the method is static (1) or instance (0).
    /// 
    /// Format:
    /// `INSTRUCTION_NAME  POOL_INDEX  METHOD_NAME  STATIC/INSTANCE?`
    private func methodInstruction(opcode: Opcode, chunk: Chunk, offset: inout Int) throws -> String {
        let constantIndex: Int
        let isStatic: Bool
        let name = String(describing: opcode)
        switch opcode {
        case .method:
            constantIndex = Int(chunk.readUInt16(offset: offset + 1))
            isStatic = chunk.readByte(offset: offset + 3) == 1 ? true : false
            offset += 4
            
        case .foreignMethod:
            constantIndex = Int(chunk.readUInt16(offset: offset + 1))
            // Note `chunk.readByte(offset: offset + 3)` is the arity (which we will ignore).
            isStatic = chunk.readByte(offset: offset + 4) == 1 ? true : false
            offset += 5
            
        default:
            throw DisassemblerError.unknownOpcode(opcode: opcode, offset: offset)
        }
        
        // The instructions name.
        var details = name.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the constant table index.
        details += String(format: "%05d", constantIndex).padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the method's name.
        details += chunk.constants[constantIndex]!.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append if this a static or instance method.
        details += isStatic ? "static" : "instance"
        
        return details
    }
    
    /// Returns the details of a simple instruction at `offset`
    /// Increments `offset` to point to the next instruction.
    ///
    /// Simple instructions are a single byte and take no operands.
    /// Format:
    /// `INSTRUCTION_NAME`
    private func simpleInstruction(opcode: Opcode, offset: inout Int) -> String {
        let name = String(describing: opcode).replacingOccurrences(of: "_", with: "")
        offset += 1
        return name.padding(toLength: COLUMN_WIDTH, withPad: " ", startingAt: 0)
    }
    
    /// Returns the details of a `superConstructor` instruction at `offset`.
    /// Increments `offset` to point to the next instruction.
    ///
    /// Prints the instruction's name, the superclass's name and the argument count.
    ///
    /// Format:
    /// `INSTRUCTION  SUPERCLASS_NAME  ARGCOUNT`
    private func superConstructor(chunk: Chunk, offset: inout Int) -> String {
        let superNameIndex = Int(chunk.readUInt16(offset: offset + 1))
        let argCount = Int(chunk.readByte(offset: offset + 3))
        
        offset += 4
        
        // The instruction's name.
        var details = "superConstructor".padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the superclass name.
        details += chunk.constants[superNameIndex]!.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the argument count.
        let argCountString = argCount.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        details += argCountString
        
        return details
    }
    
    /// Returns the details of a `superInvoke` instruction at `offset` and increments `offset` to point to the next instruction.
    ///
    /// Prints the instruction's name, the superclass's name, the method signature to invoke and the argument count.
    ///
    /// Format:
    /// `INSTRUCTION  SUPERCLASS_NAME  SIGNATURE   ARGCOUNT`
    private func superInvoke(chunk: Chunk, offset: inout Int) -> String {
        let superNameIndex = Int(chunk.readUInt16(offset: offset + 1))
        let sigIndex = Int(chunk.readUInt16(offset: offset + 3))
        let argCount = Int(chunk.readByte(offset: offset + 5))
        
        offset += 6
        
        // The instruction's name.
        var details = "superInvoke".padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the superclass name.
        details += chunk.constants[superNameIndex]!.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the signature name.
        details += chunk.constants[sigIndex]!.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the argument count.
        let argCountString = String(argCount).padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        details += argCountString
        
        return details
    }
    
    /// Returns the details of a `superSetter` instruction at `offset`
    /// Increments `offset` to point to the next instruction.
    ///
    /// Prints the instruction's name, the superclass's name and the setter signature to invoke.
    ///
    /// Format:
    /// `INSTRUCTION  SUPERCLASS_NAME  SIGNATURE`
    private func superSetter(chunk: Chunk, offset: inout Int) -> String {
        let superNameIndex = Int(chunk.readUInt16(offset: offset + 1))
        let sigIndex = Int(chunk.readUInt16(offset: offset + 3))
        
        offset += 5
        
        // The instruction's name.
        var details = "superSetter".padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the superclass name.
        details += chunk.constants[superNameIndex]!.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        // Append the signature name.
        details += chunk.constants[sigIndex]!.description.padding(toLength: 2 * COLUMN_WIDTH, withPad: " ", startingAt: 0)
        
        return details
    }
}
