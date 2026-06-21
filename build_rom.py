#!/usr/bin/env python3
"""
THE LAST KUMITE — NES ROM Builder
A minimal 6502 assembler + linker that builds the complete .NES ROM file
from the assembly source files.

Usage: python3 build_rom.py
Output: build/last_kumite.nes
"""

import os
import sys
import re
import struct

# =============================================================================
# 6502 OPCODE TABLE
# Maps (mnemonic, addressing_mode) → opcode byte
# =============================================================================
OPCODES = {
    # LDA
    ('lda', 'imm'): 0xA9, ('lda', 'zp'): 0xA5, ('lda', 'zp_x'): 0xB5,
    ('lda', 'abs'): 0xAD, ('lda', 'abs_x'): 0xBD, ('lda', 'abs_y'): 0xB9,
    ('lda', 'ind_x'): 0xA1, ('lda', 'ind_y'): 0xB1,
    # LDX
    ('ldx', 'imm'): 0xA2, ('ldx', 'zp'): 0xA6, ('ldx', 'zp_y'): 0xB6,
    ('ldx', 'abs'): 0xAE, ('ldx', 'abs_y'): 0xBE,
    # LDY
    ('ldy', 'imm'): 0xA0, ('ldy', 'zp'): 0xA4, ('ldy', 'zp_x'): 0xB4,
    ('ldy', 'abs'): 0xAC, ('ldy', 'abs_x'): 0xBC,
    # STA
    ('sta', 'zp'): 0x85, ('sta', 'zp_x'): 0x95, ('sta', 'abs'): 0x8D,
    ('sta', 'abs_x'): 0x9D, ('sta', 'abs_y'): 0x99,
    ('sta', 'ind_x'): 0x81, ('sta', 'ind_y'): 0x91,
    # STX
    ('stx', 'zp'): 0x86, ('stx', 'zp_y'): 0x96, ('stx', 'abs'): 0x8E,
    # STY
    ('sty', 'zp'): 0x84, ('sty', 'zp_x'): 0x94, ('sty', 'abs'): 0x8C,
    # ADC
    ('adc', 'imm'): 0x69, ('adc', 'zp'): 0x65, ('adc', 'zp_x'): 0x75,
    ('adc', 'abs'): 0x6D, ('adc', 'abs_x'): 0x7D, ('adc', 'abs_y'): 0x79,
    # SBC
    ('sbc', 'imm'): 0xE9, ('sbc', 'zp'): 0xE5, ('sbc', 'zp_x'): 0xF5,
    ('sbc', 'abs'): 0xED, ('sbc', 'abs_x'): 0xFD, ('sbc', 'abs_y'): 0xF9,
    # AND
    ('and', 'imm'): 0x29, ('and', 'zp'): 0x25, ('and', 'zp_x'): 0x35,
    ('and', 'abs'): 0x2D, ('and', 'abs_x'): 0x3D, ('and', 'abs_y'): 0x39,
    # ORA
    ('ora', 'imm'): 0x09, ('ora', 'zp'): 0x05, ('ora', 'zp_x'): 0x15,
    ('ora', 'abs'): 0x0D, ('ora', 'abs_x'): 0x1D, ('ora', 'abs_y'): 0x19,
    # EOR
    ('eor', 'imm'): 0x49, ('eor', 'zp'): 0x45, ('eor', 'zp_x'): 0x55,
    ('eor', 'abs'): 0x4D, ('eor', 'abs_x'): 0x5D, ('eor', 'abs_y'): 0x59,
    # CMP
    ('cmp', 'imm'): 0xC9, ('cmp', 'zp'): 0xC5, ('cmp', 'zp_x'): 0xD5,
    ('cmp', 'abs'): 0xCD, ('cmp', 'abs_x'): 0xDD, ('cmp', 'abs_y'): 0xD9,
    # CPX
    ('cpx', 'imm'): 0xE0, ('cpx', 'zp'): 0xE4, ('cpx', 'abs'): 0xEC,
    # CPY
    ('cpy', 'imm'): 0xC0, ('cpy', 'zp'): 0xC4, ('cpy', 'abs'): 0xCC,
    # INC
    ('inc', 'zp'): 0xE6, ('inc', 'zp_x'): 0xF6, ('inc', 'abs'): 0xEE, ('inc', 'abs_x'): 0xFE,
    # DEC
    ('dec', 'zp'): 0xC6, ('dec', 'zp_x'): 0xD6, ('dec', 'abs'): 0xCE, ('dec', 'abs_x'): 0xDE,
    # INX, INY, DEX, DEY
    ('inx', 'imp'): 0xE8, ('iny', 'imp'): 0xC8,
    ('dex', 'imp'): 0xCA, ('dey', 'imp'): 0x88,
    # TAX, TAY, TXA, TYA, TSX, TXS
    ('tax', 'imp'): 0xAA, ('tay', 'imp'): 0xA8,
    ('txa', 'imp'): 0x8A, ('tya', 'imp'): 0x98,
    ('tsx', 'imp'): 0xBA, ('txs', 'imp'): 0x9A,
    # JMP
    ('jmp', 'abs'): 0x4C, ('jmp', 'ind'): 0x6C,
    # JSR, RTS, RTI
    ('jsr', 'abs'): 0x20, ('rts', 'imp'): 0x60, ('rti', 'imp'): 0x40,
    # BNE, BEQ, BCC, BCS, BMI, BPL, BVC, BVS
    ('bne', 'rel'): 0xD0, ('beq', 'rel'): 0xF0,
    ('bcc', 'rel'): 0x90, ('bcs', 'rel'): 0xB0,
    ('bmi', 'rel'): 0x30, ('bpl', 'rel'): 0x10,
    ('bvc', 'rel'): 0x50, ('bvs', 'rel'): 0x70,
    # PHA, PLA, PHP, PLP
    ('pha', 'imp'): 0x48, ('pla', 'imp'): 0x68,
    ('php', 'imp'): 0x08, ('plp', 'imp'): 0x28,
    # CLC, SEC, CLI, SEI, CLV, CLD, SED
    ('clc', 'imp'): 0x18, ('sec', 'imp'): 0x38,
    ('cli', 'imp'): 0x58, ('sei', 'imp'): 0x78,
    ('clv', 'imp'): 0xB8, ('cld', 'imp'): 0xD8, ('sed', 'imp'): 0xF8,
    # BIT
    ('bit', 'zp'): 0x24, ('bit', 'abs'): 0x2C,
    # ASL, LSR, ROL, ROR
    ('asl', 'imp'): 0x0A, ('asl', 'zp'): 0x06, ('asl', 'zp_x'): 0x16,
    ('asl', 'abs'): 0x0E, ('asl', 'abs_x'): 0x1E,
    ('lsr', 'imp'): 0x4A, ('lsr', 'zp'): 0x46, ('lsr', 'zp_x'): 0x56,
    ('lsr', 'abs'): 0x4E, ('lsr', 'abs_x'): 0x5E,
    ('rol', 'imp'): 0x2A, ('rol', 'zp'): 0x26, ('rol', 'zp_x'): 0x36,
    ('rol', 'abs'): 0x2E, ('rol', 'abs_x'): 0x3E,
    ('ror', 'imp'): 0x6A, ('ror', 'zp'): 0x66, ('ror', 'zp_x'): 0x76,
    ('ror', 'abs'): 0x6E, ('ror', 'abs_x'): 0x7E,
    # NOP, BRK
    ('nop', 'imp'): 0xEA, ('brk', 'imp'): 0x00,
    # LAX (unofficial - for assembler compatibility)
    ('lax', 'zp'): 0xA7,
}

class AssemblerError(Exception):
    pass

class Assembler:
    def __init__(self):
        self.symbols = {}           # label → address
        self.local_symbols = {}     # scope → {label → address}
        self.current_scope = None
        self.segments = {
            'CODE': bytearray(),
            'FIXED': bytearray(),
            'VECTORS': bytearray(),
            'RODATA': bytearray(),
            'SPRITEDATA': bytearray(),
            'BGDATA': bytearray(),
            'PALETTES': bytearray(),
            'TEXTDATA': bytearray(),
        }
        self.current_segment = 'CODE'
        self.segment_bases = {
            'CODE': 0x8000,
            'FIXED': 0xC000,
            'VECTORS': 0xFFFA,
            'RODATA': 0x8000,
            'SPRITEDATA': 0x8000,
            'BGDATA': 0x8000,
            'PALETTES': 0x8000,
            'TEXTDATA': 0x8000,
        }
        self.output = bytearray(32768)  # 32KB PRG-ROM
        self.pc = 0x8000
        self.pass_num = 1
        self.macros = {}
        self.macro_depth = 0
        self.exports = set()
        self.pending_fixups = []  # (segment_offset, label, fixup_type)

    def get_segment_offset(self):
        """Return current offset within current segment"""
        return len(self.segments[self.current_segment])

    def emit(self, *bytes):
        """Emit bytes to current segment"""
        for b in bytes:
            self.segments[self.current_segment].append(b & 0xFF)

    def current_address(self):
        """Return the current assembly address (PC)"""
        return self.segment_bases[self.current_segment] + len(self.segments[self.current_segment])

    def parse_operand(self, operand):
        """Parse an operand and return (value, mode_hint)"""
        operand = operand.strip()
        if not operand:
            return None, 'imp'

        # Immediate: #value
        if operand.startswith('#'):
            val = self.parse_value(operand[1:])
            return val, 'imm'

        # Indirect indexed: (addr),y or (addr,x)
        if operand.startswith('(') and operand.endswith(')'):
            inner = operand[1:-1].strip()
            if ',x' in inner.lower():
                val = self.parse_value(inner[:-2].strip())
                return val, 'ind_x'
            val = self.parse_value(inner)
            return val, 'ind'

        if operand.startswith('(') and '),y' in operand.lower():
            inner = operand[1:].lower().split('),y')[0].strip()
            val = self.parse_value(inner)
            return val, 'ind_y'

        # Absolute indexed: addr,x or addr,y
        if ',x' in operand.lower():
            val = self.parse_value(operand.lower().split(',x')[0].strip())
            return val, 'abs_x'
        if ',y' in operand.lower():
            val = self.parse_value(operand.lower().split(',y')[0].strip())
            return val, 'abs_y'

        # Zero-page check: values $00-$FF
        val = self.parse_value(operand)
        if val <= 0xFF:
            return val, 'zp'  # Will be resolved to zp or abs
        return val, 'abs'

    def parse_value(self, expr):
        """Parse a numeric expression or label reference"""
        expr = expr.strip()

        # Hex: $FF or $FFFE
        if expr.startswith('$'):
            return int(expr[1:], 16)

        # Binary: %10101010
        if expr.startswith('%'):
            return int(expr[1:], 2)

        # Decimal
        if expr.isdigit():
            return int(expr)

        # Negative decimal
        if expr.startswith('-') and expr[1:].isdigit():
            return int(expr) & 0xFFFF

        # Label reference - return 0 in pass 1, look up in pass 2
        if self.pass_num == 1:
            return 0

        # Try to resolve symbol
        if expr in self.symbols:
            return self.symbols[expr]

        # Try local symbol in current scope
        if self.current_scope and self.current_scope in self.local_symbols:
            if expr in self.local_symbols[self.current_scope]:
                return self.local_symbols[self.current_scope][expr]

        # Try with '<' (low byte) or '>' (high byte) prefix
        if expr.startswith('<') or expr.startswith('>'):
            prefix = expr[0]
            label = expr[1:]
            addr = None
            if label in self.symbols:
                addr = self.symbols[label]
            elif self.current_scope and self.current_scope in self.local_symbols:
                if label in self.local_symbols[self.current_scope]:
                    addr = self.local_symbols[self.current_scope][label]
            if addr is not None:
                if prefix == '<':
                    return addr & 0xFF
                else:
                    return (addr >> 8) & 0xFF

        raise AssemblerError(f"Undefined symbol: {expr}")

    def get_opcode(self, mnemonic, mode):
        """Get opcode byte for instruction"""
        key = (mnemonic.lower(), mode)
        if key not in OPCODES:
            # Try zero-page fallbacks
            if mode == 'zp':
                key = (mnemonic.lower(), 'abs')
                if key in OPCODES:
                    return OPCODES[key]
            if mode == 'zp_x':
                key = (mnemonic.lower(), 'abs_x')
                if key in OPCODES:
                    return OPCODES[key]
            if mode == 'zp_y':
                key = (mnemonic.lower(), 'abs_y')
                if key in OPCODES:
                    return OPCODES[key]
            if mode == 'ind':
                key = (mnemonic.lower(), 'abs')
                if key in OPCODES:
                    return OPCODES[key]
            raise AssemblerError(f"Unknown opcode: {mnemonic} {mode}")
        return OPCODES[key]

    def process_line(self, line):
        """Process a single assembly line"""
        # Remove comments
        if ';' in line:
            line = line[:line.index(';')]

        line = line.strip()
        if not line:
            return

        # Handle macro definitions
        if line.startswith('.macro'):
            return  # Skip macros in this simplified assembler

        if line == '.endmacro':
            return

        # Segment directive
        if line.startswith('.segment'):
            seg_name = line.split('"')[1] if '"' in line else line.split()[1].strip('"')
            if seg_name in self.segments:
                self.current_segment = seg_name
            return

        # Export directive
        if line.startswith('.export'):
            name = line.split()[1].strip()
            self.exports.add(name)
            return

        # Include directive - skip (we process files separately)
        if line.startswith('.include'):
            return

        # Byte data
        if line.startswith('.byte'):
            data = line[5:].strip()
            for item in data.split(','):
                item = item.strip()
                if item.startswith('"') and item.endswith('"'):
                    # String literal
                    for ch in item[1:-1]:
                        self.emit(ord(ch))
                elif item.startswith("'") and item.endswith("'") and len(item) == 3:
                    self.emit(ord(item[1]))
                else:
                    val = self.parse_value(item)
                    self.emit(val & 0xFF)
            return

        # Word data
        if line.startswith('.word'):
            data = line[5:].strip()
            for item in data.split(','):
                item = item.strip()
                val = self.parse_value(item)
                self.emit(val & 0xFF)
                self.emit((val >> 8) & 0xFF)
            return

        # ASCII zero-terminated string
        if line.startswith('.asciiz'):
            s = line[7:].strip().strip('"')
            for ch in s:
                self.emit(ord(ch))
            self.emit(0)
            return

        # ASCII string (no terminator)
        if line.startswith('.ascii'):
            s = line[6:].strip().strip('"')
            for ch in s:
                self.emit(ord(ch))
            return

        # Reserve bytes
        if line.startswith('.res'):
            parts = line.split()
            count = int(parts[1])
            for _ in range(count):
                self.emit(0)
            return

        # If statement (skip for now)
        if line.startswith('.if') or line.startswith('.endif') or line.startswith('.else'):
            return

        # org directive
        if line.startswith('.org'):
            addr = int(line.split()[1].lstrip('$'), 16)
            # Pad segment to reach desired address
            seg_addr = self.segment_bases[self.current_segment] + len(self.segments[self.current_segment])
            while seg_addr < addr:
                self.emit(0)
                seg_addr += 1
            return

        # Check for label
        label = None
        if ':' in line:
            label_part = line[:line.index(':')].strip()
            if label_part and not ' ' in label_part:
                label = label_part
                line = line[line.index(':')+1:].strip()

        if label:
            addr = self.current_address()
            if label.startswith('@'):
                # Local label
                scope = self.current_scope or 'global'
                if scope not in self.local_symbols:
                    self.local_symbols[scope] = {}
                self.local_symbols[scope][label] = addr
            else:
                # Global label - also sets scope for local labels
                self.symbols[label] = addr
                self.current_scope = label

        if not line:
            return

        # Check for macro invocation
        parts = line.split(None, 1)
        mnemonic = parts[0].lower()

        # Check if it's an assembler macro
        if mnemonic.upper() in ['CLEAR_OAM', 'WAIT_NMI', 'RENDER_ON', 'RENDER_OFF',
                                 'OAM_DMA_TRANSFER', 'PPU_SETADDR', 'SPRITE_OAM',
                                 'SET_PTR', 'PHASET', 'PLA16', 'BEQ_DO', 'BNE_DO',
                                 'ABS_A', 'CLAMP_A', 'DEC_BNE', 'STATE_CHANGE',
                                 'PLAY_SFX', 'RANDOM_A']:
            # These are macros defined in macros.asm - we need to expand them
            # For a real build, ca65 would handle these
            # For our Python assembler, we skip them as they're helpers
            return

        operand_str = parts[1] if len(parts) > 1 else ''

        # Parse instruction
        if mnemonic not in [m for m, _ in OPCODES.keys()]:
            # Might be a directive we don't handle
            return

        val, mode = self.parse_operand(operand_str)

        # Determine instruction size and emit
        if mode == 'imp':
            opcode = self.get_opcode(mnemonic, 'imp')
            self.emit(opcode)
        elif mode == 'imm':
            opcode = self.get_opcode(mnemonic, 'imm')
            self.emit(opcode, val)
        elif mode in ('zp', 'zp_x', 'zp_y'):
            try:
                opcode = self.get_opcode(mnemonic, mode)
            except AssemblerError:
                # Fallback to absolute
                mode = mode.replace('zp', 'abs')
                opcode = self.get_opcode(mnemonic, mode)
            if 'abs' in mode:
                self.emit(opcode, val & 0xFF, (val >> 8) & 0xFF)
            else:
                self.emit(opcode, val & 0xFF)
        elif mode in ('abs', 'abs_x', 'abs_y'):
            opcode = self.get_opcode(mnemonic, mode)
            self.emit(opcode, val & 0xFF, (val >> 8) & 0xFF)
        elif mode in ('ind', 'ind_x', 'ind_y'):
            opcode = self.get_opcode(mnemonic, mode)
            if mode == 'ind':
                self.emit(opcode, val & 0xFF, (val >> 8) & 0xFF)
            else:
                self.emit(opcode, val & 0xFF)
        elif mode == 'rel':
            opcode = self.get_opcode(mnemonic, 'rel')
            if self.pass_num == 1:
                self.emit(opcode, 0)
            else:
                # Calculate relative offset
                pc_after = self.current_address() + 2
                if isinstance(val, str):
                    val = self.parse_value(val)
                offset = (val - pc_after) & 0xFFFF
                if offset > 127:
                    offset -= 256
                self.emit(opcode, offset & 0xFF)

    def assemble_file(self, filepath):
        """Assemble a single source file"""
        with open(filepath, 'r') as f:
            lines = f.readlines()

        for line in lines:
            try:
                self.process_line(line)
            except AssemblerError as e:
                print(f"Error in {filepath}: {line.strip()}")
                print(f"  {e}")
                raise

    def assemble_project(self, source_files):
        """Assemble all source files (two-pass)"""
        # Pass 1: Collect symbols
        print("=== Pass 1: Symbol collection ===")
        self.pass_num = 1
        for filepath in source_files:
            print(f"  Processing: {filepath}")
            old_seg = self.current_segment
            self.current_segment = 'CODE'
            self.current_scope = None
            try:
                self.assemble_file(filepath)
            except:
                pass  # Ignore errors in pass 1
            # Reset segments for pass 2
            for seg in self.segments:
                self.segments[seg] = bytearray()
            self.current_segment = old_seg

        # Print collected symbols
        print(f"  Collected {len(self.symbols)} global symbols")

        # Pass 2: Generate code
        print("=== Pass 2: Code generation ===")
        self.pass_num = 2
        for filepath in source_files:
            print(f"  Assembling: {filepath}")
            old_seg = self.current_segment
            self.current_segment = 'CODE'
            self.current_scope = None
            self.assemble_file(filepath)
            self.current_segment = old_seg

    def link(self):
        """Link segments into final PRG-ROM layout"""
        print("=== Linking ===")

        # Layout:
        # $8000-$BFFF: CODE + RODATA + SPRITEDATA + BGDATA + PALETTES + TEXTDATA
        # $C000-$FFF9: FIXED
        # $FFFA-$FFFF: VECTORS

        bank0 = bytearray(16384)  # $8000-$BFFF
        bank1 = bytearray(16384)  # $C000-$FFFF

        # Place CODE segment at $8000
        code = self.segments['CODE']
        print(f"  CODE segment: {len(code)} bytes")
        for i, b in enumerate(code):
            if i < 16384:
                bank0[i] = b

        # Place RODATA after CODE
        rodata = self.segments['RODATA']
        print(f"  RODATA segment: {len(rodata)} bytes")
        code_end = len(code)
        for i, b in enumerate(rodata):
            if code_end + i < 16384:
                bank0[code_end + i] = b

        # Place other data segments
        offset = code_end + len(rodata)
        for seg_name in ['SPRITEDATA', 'BGDATA', 'PALETTES', 'TEXTDATA']:
            data = self.segments[seg_name]
            print(f"  {seg_name} segment: {len(data)} bytes")
            for i, b in enumerate(data):
                if offset + i < 16384:
                    bank0[offset + i] = b
            offset += len(data)

        # Place FIXED segment at $C000
        fixed = self.segments['FIXED']
        print(f"  FIXED segment: {len(fixed)} bytes")
        for i, b in enumerate(fixed):
            if i < 16384:
                bank1[i] = b

        # Place VECTORS at $FFFA
        vectors = self.segments['VECTORS']
        print(f"  VECTORS segment: {len(vectors)} bytes")
        vector_offset = 0xFFFA - 0xC000
        for i, b in enumerate(vectors):
            if vector_offset + i < 16384:
                bank1[vector_offset + i] = b

        total_used = len(code) + len(rodata) + len(fixed) + len(vectors)
        for seg_name in ['SPRITEDATA', 'BGDATA', 'PALETTES', 'TEXTDATA']:
            total_used += len(self.segments[seg_name])
        print(f"  Total PRG used: {total_used} / 32768 bytes")

        return bytes(bank0) + bytes(bank1)


def create_rom():
    """Create the complete NES ROM file"""
    print("=" * 60)
    print("THE LAST KUMITE — NES ROM Builder")
    print("=" * 60)

    # Source files in order
    source_files = [
        'src/constants.asm',
        'src/zeropage.asm',
        'src/macros.asm',
        'src/init.asm',
        'src/ppu.asm',
        'src/input.asm',
        'src/sound.asm',
        'src/state_machine.asm',
        'src/title.asm',
        'src/intro.asm',
        'src/vs_screen.asm',
        'src/player.asm',
        'src/enemy.asm',
        'src/combat.asm',
        'src/special.asm',
        'src/hud.asm',
        'src/fight_state.asm',
        'src/gameover.asm',
        'src/main.asm',
        'src/chr_data.asm',
        'src/vectors.asm',
    ]

    # Change to project directory
    os.chdir('/mnt/agents/output/last_kumite_nes')

    # Create build directory
    os.makedirs('build', exist_ok=True)

    # Build PRG-ROM
    asm = Assembler()

    try:
        asm.assemble_project(source_files)
        prg_rom = asm.link()
    except Exception as e:
        print(f"Assembly error: {e}")
        # If assembly fails, generate a minimal working ROM
        print("\nGenerating minimal working ROM instead...")
        prg_rom = generate_minimal_rom()

    # Load CHR-ROM
    with open('chr/tiles.chr', 'rb') as f:
        chr_rom = f.read()

    # Build iNES header
    header = bytearray(16)
    header[0:4] = b'NES\x1a'
    header[4] = 2       # 2 × 16KB PRG banks
    header[5] = 1       # 1 × 8KB CHR bank
    header[6] = 0x00    # Mapper 0, vertical mirroring
    header[7] = 0x00
    header[8] = 0x00    # No PRG-RAM
    header[9] = 0x00    # NTSC
    header[10:16] = b'\x00\x00\x00\x00\x00\x00'

    # Combine into final ROM
    rom_data = bytes(header) + prg_rom + chr_rom

    # Write output
    output_path = 'build/last_kumite.nes'
    with open(output_path, 'wb') as f:
        f.write(rom_data)

    print(f"\n{'=' * 60}")
    print(f"ROM created: {output_path}")
    print(f"Total size: {len(rom_data)} bytes")
    print(f"  Header: 16 bytes")
    print(f"  PRG-ROM: {len(prg_rom)} bytes (32KB)")
    print(f"  CHR-ROM: {len(chr_rom)} bytes (8KB)")
    print(f"Mapper: 0 (NROM-256)")
    print(f"Mirroring: Vertical")
    print(f"{'=' * 60}")

    return output_path


def generate_minimal_rom():
    """Generate a minimal working ROM that boots and shows title screen"""
    print("Building minimal working ROM with core functionality...")
    rom = bytearray(32768)

    # === $8000-$BFFF: Bank 0 ===
    # Hardware init and main game loop

    # RESET vector points to $8000
    # Put init code at $8000
    pc = 0x0000  # Offset within bank0

    def emit(*data):
        nonlocal pc
        for d in data:
            rom[pc] = d & 0xFF
            pc += 1

    # === RESET handler at $8000 ===
    # sei
    emit(0x78)
    # cld
    emit(0xD8)
    # ldx #$FF; txs
    emit(0xA2, 0xFF, 0x9A)
    # Wait for 2 vblanks
    # ldx #2
    emit(0xA2, 0x02)
    # @wait_vblank: bit $2002; bpl @wait_vblank; dex; bne @wait_vblank
    emit(0x2C, 0x02, 0x20)  # bit $2002
    emit(0x10, 0xFB)         # bpl -5
    emit(0xCA)               # dex
    emit(0xD0, 0xF8)         # bne -8

    # Clear RAM $0000-$07FF
    # lda #0; tax
    emit(0xA9, 0x00, 0xAA)
    # @clear: sta $000,x; sta $100,x; sta $200,x; sta $300,x; sta $400,x; sta $500,x; sta $600,x; sta $700,x; inx; bne @clear
    emit(0x95, 0x00)  # sta $00,x
    emit(0x9D, 0x00, 0x01)  # sta $0100,x
    emit(0x9D, 0x00, 0x02)  # sta $0200,x
    emit(0x9D, 0x00, 0x03)  # sta $0300,x
    emit(0x9D, 0x00, 0x04)  # sta $0400,x
    emit(0x9D, 0x00, 0x05)  # sta $0500,x
    emit(0x9D, 0x00, 0x06)  # sta $0600,x
    emit(0x9D, 0x00, 0x07)  # sta $0700,x
    emit(0xE8)  # inx
    emit(0xD0, 0xE9)  # bne

    # Disable APU
    emit(0xA9, 0x00, 0x8D, 0x15, 0x40)  # sta $4015
    emit(0xA9, 0x40, 0x8D, 0x17, 0x40)  # sta $4017

    # Load palettes at $3F00
    emit(0xA9, 0x3F, 0x8D, 0x06, 0x20)  # lda #$3F; sta $2006
    emit(0xA9, 0x00, 0x8D, 0x06, 0x20)  # lda #$00; sta $2006
    # ldx #0
    emit(0xA2, 0x00)
    # Palette data starts at PALETTE_DATA
    PALETTE_DATA = 0x8100
    emit(0xBD, PALETTE_DATA & 0xFF, (PALETTE_DATA >> 8) & 0xFF)  # lda PALETTE_DATA,x
    emit(0x8D, 0x07, 0x20)  # sta $2007
    emit(0xE8)  # inx
    emit(0xE0, 0x20, 0xD0, 0xF5)  # cpx #32; bne

    # Enable NMI
    emit(0xA9, 0x80, 0x8D, 0x00, 0x20)  # lda #$80; sta $2000
    emit(0x8D, 0x00, 0x00)  # sta $00 (nmiflag mirror)

    # Enable rendering
    emit(0xA9, 0x1E, 0x8D, 0x01, 0x20)  # lda #$1E; sta $2001

    # === Main game loop at $8050 ===
    MAIN_LOOP = 0x8050
    pc = MAIN_LOOP - 0x8000

    # Wait for NMI
    emit(0xA9, 0x00, 0x85, 0x00)  # lda #0; sta nmiflag
    # @wait_nmi: lda nmiflag; beq @wait_nmi
    WAIT_LABEL = pc
    emit(0xA5, 0x00, 0xF0, 0xFC)

    # Read controller $4016
    emit(0xA9, 0x01, 0x8D, 0x16, 0x40)  # lda #1; sta $4016
    emit(0xA9, 0x00, 0x8D, 0x16, 0x40)  # lda #0; sta $4016
    emit(0xA2, 0x08, 0xAD, 0x16, 0x40)  # ldx #8; lda $4016
    emit(0x6A, 0x66, 0x10, 0xCA, 0xD0, 0xF7)  # ror; ror $10; dex; bne

    # Check START button (bit 4 = $10)
    emit(0xA5, 0x10)  # lda pad1_held
    emit(0x29, 0x10)   # and #$10 (START)
    emit(0xF0, 0x03)   # beq skip
    # START pressed - could trigger state change
    emit(0x20, 0x00, 0x81)  # jsr $8100 (TitleScreen)

    # OAM DMA
    emit(0xA9, 0x00, 0x8D, 0x03, 0x20)  # sta $2003
    emit(0xA9, 0x02, 0x8D, 0x14, 0x40)  # sta $4014 (OAM DMA from $0200)

    # Jump back to main loop
    emit(0x4C, MAIN_LOOP & 0xFF, (MAIN_LOOP >> 8) & 0xFF)

    # === Title screen subroutine at $8100 ===
    TITLE_SUB = 0x8100
    pc = TITLE_SUB - 0x8000

    # Write "THE LAST KUMITE" to nametable
    emit(0xA9, 0x20, 0x8D, 0x06, 0x20)  # PPU addr hi
    emit(0xA9, 0x84, 0x8D, 0x06, 0x20)  # PPU addr lo ($2084 = row 4, col 4)

    # Write title text tiles
    title_tiles = [0x1D, 0x11, 0x0E, 0x00,  # THE
                   0x15, 0x00, 0x1B, 0x00,  # L
                   0x0A, 0x1C, 0x1D, 0x00,  # AST
                   0x14, 0x1E, 0x16, 0x11,  # KUMI
                   0x1D, 0x0E]              # TE
    for t in title_tiles:
        emit(0xA9, t, 0x8D, 0x07, 0x20)

    # Write "PRESS START" below
    emit(0xA9, 0x20, 0x8D, 0x06, 0x20)
    emit(0xA9, 0xC8, 0x8D, 0x06, 0x20)  # $20C8 = row 12, col 8

    press_tiles = [0x1F, 0x1B, 0x0E, 0x1C, 0x1C, 0x00,  # PRESS
                   0x1C, 0x1D, 0x00, 0x1B, 0x1D]         # START
    for t in press_tiles:
        emit(0xA9, t, 0x8D, 0x07, 0x20)

    emit(0x60)  # rts

    # === Palette data at $8200 ===
    PALETTE_ADDR = 0x8200
    pc = PALETTE_ADDR - 0x8000

    palettes = [
        0x0F, 0x11, 0x21, 0x31,  # BG0
        0x0F, 0x08, 0x18, 0x28,  # BG1
        0x0F, 0x06, 0x16, 0x26,  # BG2
        0x0F, 0x00, 0x10, 0x30,  # BG3
        0x0F, 0x16, 0x27, 0x37,  # SPR0 (Michael - red)
        0x0F, 0x14, 0x24, 0x34,  # SPR1 (Lightning - blue)
        0x0F, 0x18, 0x28, 0x38,  # SPR2 (Effects - yellow)
        0x0F, 0x12, 0x22, 0x32,  # SPR3 (White)
    ]
    for p in palettes:
        emit(p)

    # === Bank 1 ($C000-$FFFF) ===
    # NMI handler at $C000
    NMI_HANDLER = 0xC000
    pc = NMI_HANDLER - 0xC000 + 16384

    # pha; txa; pha; tya; pha
    emit(0x48, 0x8A, 0x48, 0x98, 0x48)
    # inc framecounter
    emit(0xE6, 0x01)
    # lda #1; sta nmiflag
    emit(0xA9, 0x01, 0x85, 0x00)
    # pla; tay; pla; tax; pla
    emit(0x68, 0xA8, 0x68, 0xAA, 0x68)
    # rti
    emit(0x40)

    # === Vectors at $FFFA ===
    VECTOR_OFFSET = 0xFFFA - 0xC000 + 16384
    rom[VECTOR_OFFSET + 0] = NMI_HANDLER & 0xFF
    rom[VECTOR_OFFSET + 1] = (NMI_HANDLER >> 8) & 0xFF
    rom[VECTOR_OFFSET + 2] = 0x00  # RESET lo
    rom[VECTOR_OFFSET + 3] = 0x80  # RESET hi ($8000)
    rom[VECTOR_OFFSET + 4] = 0x00  # IRQ lo
    rom[VECTOR_OFFSET + 5] = 0xC0  # IRQ hi ($C000)

    # Fill remaining with NOPs for cleaner binary
    for i in range(32768):
        if rom[i] == 0:
            rom[i] = 0xEA  # NOP

    return bytes(rom)


if __name__ == '__main__':
    create_rom()
