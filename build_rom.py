#!/usr/bin/env python3
"""
THE LAST KUMITE — iNES header + final ROM assembly.

Takes the linked raw PRG binary (produced by ld65) and the CHR data file
(produced by tools/chr_convert.py), prepends a correct 16-byte iNES header,
and writes the final TheLastKumite.nes ROM.

This is the ONLY thing this script does — it is not an assembler. Actual
6502 assembly is handled entirely by ca65/ld65 (see Makefile). An earlier
version of this project had a custom from-scratch 6502 assembler living
under this filename; it could not correctly assemble the real source and
silently fell back to emitting a near-empty stub ROM on failure. That code
has been removed entirely rather than fixed, since ca65/ld65 already do
this job correctly and there is no reason to maintain a parallel assembler.

Usage: build_rom.py <raw_prg.bin> <tiles.chr> <output.nes>
"""
import sys

def main():
    if len(sys.argv) != 4:
        print("Usage: build_rom.py <raw_prg.bin> <tiles.chr> <output.nes>")
        sys.exit(1)

    raw_path, chr_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(raw_path, "rb") as f:
        prg = f.read()
    with open(chr_path, "rb") as f:
        chr_data = f.read()

    if len(prg) != 32768:
        print(f"ERROR: expected 32768-byte PRG-ROM, got {len(prg)} bytes. "
              f"Check last_kumite.cfg PRG0/PRG1 region sizes.")
        sys.exit(1)
    if len(chr_data) != 8192:
        print(f"ERROR: expected 8192-byte CHR-ROM, got {len(chr_data)} bytes "
              f"from {chr_path}.")
        sys.exit(1)

    header = bytearray(16)
    header[0:4] = b"NES\x1a"   # iNES signature
    header[4] = 2              # PRG-ROM: 2 x 16KB = 32KB
    header[5] = 1              # CHR-ROM: 1 x 8KB = 8KB
    header[6] = 0x00           # Flags 6: mapper 0 (NROM), horizontal mirroring
    header[7] = 0x00           # Flags 7: mapper 0 high nibble, NES 2.0 off
    header[8] = 0x00           # PRG-RAM size (none)
    header[9] = 0x00           # TV system: NTSC
    # bytes 10-15 left as zero padding

    with open(out_path, "wb") as out:
        out.write(bytes(header))
        out.write(prg)
        out.write(chr_data)

    total = 16 + len(prg) + len(chr_data)
    print(f"ROM written: {out_path} ({total} bytes)")


if __name__ == "__main__":
    main()
