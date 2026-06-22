#!/usr/bin/env python3
"""
One-time helper: extract pattern table 0 (background/UI/font tiles, the
first 4096 bytes) from the previously-working chr/tiles.chr and save it as
chr/tiles_bg.chr, which tools/chr_convert.py uses as the unchanging
background half when rebuilding the full CHR ROM with new sprite art.

Usage: python3 tools/extract_bg_bank.py <path_to_old_tiles.chr>
"""
import os
import sys

BANK_BYTES = 4096


def main():
    if len(sys.argv) != 2:
        print("Usage: extract_bg_bank.py <path_to_old_tiles.chr>")
        sys.exit(1)
    src = sys.argv[1]
    with open(src, "rb") as f:
        data = f.read()
    if len(data) < BANK_BYTES:
        raise SystemExit(f"ERROR: {src} is smaller than one pattern table ({len(data)} bytes)")
    bg_bank = data[:BANK_BYTES]
    out_path = os.path.join(os.path.dirname(__file__), "..", "chr", "tiles_bg.chr")
    with open(out_path, "wb") as f:
        f.write(bg_bank)
    print(f"Wrote {out_path} ({len(bg_bank)} bytes)")


if __name__ == "__main__":
    main()
